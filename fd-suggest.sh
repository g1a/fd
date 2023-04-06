function fd-suggest {
  FDPATH=$(cd $HOME; find . -maxdepth 5 -type d \( -path './Library' -o -path '*/vendor' -o -path './Downloads' -o -path './.*' -o -path '*/tmp' \) -prune -o -name ".git" -print | sed -e 's#^./##' | grep '/[^/]*/' | sed -e 's#/[^/]*/.git$##' | sort | uniq | sed -e 's/^/"/' -e 's/$/:"\\/g')
  echo "export FDPATH=\\"
  echo "$FDPATH"
  echo '"."'
}
