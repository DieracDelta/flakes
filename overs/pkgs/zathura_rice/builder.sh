export PATH="$coreutils/bin"
mkdir -p $out/bin/
cp $src/gen_rc.sh $out/bin/
cp $src/zathura_pywal.sh $out/bin/zathura_pwyal.sh
chmod u+x $out/bin/gen_rc.sh
chmod u+x $out/bin/zathura_pwyal.sh

