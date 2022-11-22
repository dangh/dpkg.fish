function dpkg -d 'install package without root'
  argparse -i i/install r/remove -- $argv
  if set -q _flag_install
    for f in $argv
      switch $f
      case '*.deb'
        _dpkg_install_deb $f
      case '*.tar.gz'
        _dpkg_install_tarball $f
      case '*.AppImage'
        _dpkg_install_appimage $f
      end
    end
  else if set -q _flag_remove
    for f in $argv
      _dpkg_remove $f
    end
  end
end

function _dpkg_install_deb -a url
  # fetch
  set -l dir (mktemp -d)
  if not wget -q --show-progress -P $dir $url
    echo failed to download deb package $url
    return 1
  end
  set -l f $dir/*
  # extract
  if not command dpkg -x $f $dir/local
    echo failed to extract deb package $f
    return 1
  end
  # install
  _dpkg_install_dir $dir/local
end

function _dpkg_install_tarball -a url
  # fetch
  set -l dir (mktemp -d)
  if not wget -q --show-progress -P $dir $url
    echo failed to download tarball $url
    return 1
  end
  set -l f $dir/*
  # extract
  if not command tar -xvf $f -C $dir/local
    echo failed to extract tarball $f
    return 1
  end
  # install
  _dpkg_install_dir $dir/local
end

function _dpkg_install_appimage -a url
  # fetch
  set -l dir (mktemp -d)
  if not wget -q --show-progress -P $dir $url
    echo failed to download app image $url
    return 1
  end
  set -l f $dir/*
  # extract
  if not fish -c "
    chmod +x $f
    cd $dir
    $f --appimage-extract
  " > /dev/null
    echo failed to extract app image $f
    return 1
  end
  # install
  _dpkg_install_dir $dir/squashfs-root/usr
end

function _dpkg_install_dir -a dir
  test -d $dir || return 1
  # normalize paths
  if test -d $dir/usr
    rsync -avu $dir/usr/ $dir
    rm -r $dir/usr
  end > /dev/null
  # get package name
  set -l pkg
  if test -d $dir/bin
    for f in $dir/bin/*
      if test -z "$pkg" -o (string length (path basename $f)) -lt (string length "$pkg")
        set pkg (path basename $f)
      end
    end
  end
  if test -z "$pkg"
    echo unknown package name!
    return 1
  end
  # install to home dir
  echo
  rsync -avIi $dir/ $HOME/.local/ | grep '>f' | cut -d' ' -f2- | tee $HOME/.config/dpkg/$pkg
  echo
end

function _dpkg_remove -a pkg
  if not test -f $HOME/.config/dpkg/$pkg
    echo package $pkg does not exist!
    return 1
  end
  # remove package files
  while read -l f
    rm -vf $HOME/.local/$f
  end < $HOME/.config/dpkg/$pkg
  # remove track file
  rm -vf $HOME/.config/dpkg/$pkg
  # cleanup empty dirs
  find $HOME/.local -type d -empty -delete
end
