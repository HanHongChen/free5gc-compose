# 下載 ell 並安裝
apt-get install -y git build-essential pkg-config m4 autoconf automake libtool autoconf-archive gettext libtool-bin
git clone git://git.kernel.org/pub/scm/libs/ell/ell.git
cd ell
git checkout 0.52
./bootstrap
./configure --prefix=/usr
make -j$(nproc)
make install
cd ..

# 下載 mptcpd 並進入資料夾
git clone https://github.com/multipath-tcp/mptcpd.git
cd mptcpd
git checkout v0.12
./bootstrap



# 編譯安裝 mptcpd
./configure
make -j$(nproc)
make install

# 5. 用 foreground 方式啟動 mptcpd
# 不用 systemctl，直接執行
# export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH
# mptcpd