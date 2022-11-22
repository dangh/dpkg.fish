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

function _dpkg_install
  set -l packages $argv
  set -l tmpdir (mktemp -d)
  # download packages
  mkdir -p $tmpdir/src
  wget -P $tmpdir/src $packages
  # extract packages
  mkdir $tmpdir/extract
  for f in $tmpdir/src/*
    switch $f
      case '*.deb'
        _dpkg_install_deb $f
      case '*.tar.gz'
        _dpkg_install_tar $f
      case '*.AppImage'
        _dpkg_install_appimage $f
    end
  end
end

function _dpkg_install_deb -a url
  # fetch
  set -l dir (mktemp -d)
  wget -P $dir $url
  set -l f $dir/*
  # extract
  command dpkg -x $f $dir/local
  # install
  _dpkg_install_dir $dir/local
end

function _dpkg_install_tarball -a url
  # fetch
  set -l dir (mktemp -d)
  wget -P $dir $url
  set -l f $dir/*
  # extract
  command tar -xvf $f -C $dir/local
  # install
  _dpkg_install_dir $dir/local
end

function _dpkg_install_appimage -a url
  # fetch
  set -l dir (mktemp -d)
  wget -P $dir $url
  set -l f $dir/*
  # extract
  fish -c "
    chmod +x $f
    cd $dir
    $f --appimage-extract
  "
  # install
  _dpkg_install_dir $dir/squashfs-root/usr
end

function _dpkg_install_dir -a dir
  # normalize paths
  if test -d $dir/usr
    rsync -avg $dir/usr $dir
    rm -r $dir/usr
  end
  # install to home dir
  rsync -avu $dir/ $HOME/.local/
  # get package name
  set -l pkg
  if test -d $dir/bin
    for f in $dir/bin/*
      if test (string length (path basename $f)) -lt (string length "$pkg")
        set pkg (path basename $f)
      end
    end
  end
  # keep track of install files
  if test -n "$pkg"
    mkdir -p $HOME/.config/dpkg
    fish -c "
      cd $dir
      find . -type d | sed -e 's/.\///' > $HOME/.config/dpkg/$pkg
    "
  end
end

function _dpkg_remove -a pkg
  test -f $HOME/.config/dpkg/$pkg || exit 1
  while read -z -l f
    rm -f $HOME/.local/$f
  end < $HOME/.config/dpkg/$pkg
  rm $HOME/.config/dpkg/$pkg
end
