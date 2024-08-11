■slackware64-current(x86-64)上のクロスコンパイル環境の作り方

1. slackware64-current をインストール 
   (でなくとも、glib-2.38 を使っている x86-64 のディストリビューションなら多分大丈夫)
2. cross-toolchain-for-slackware64-current.tar.xz を/で展開
   (/usr/src/CROSS ディレクトリができて、その中にツールチェインが入る)
3. mkdir -p /usr/src/Pico して cd /usr/src/Pico でPicoディレクトリに移動。
4. ここにある *.patch, *.sh をここへコピー、 chmod +x *.sh する。
5. pico_setup_for_cross.sh をこのディレクトリで実行
   (Pico SDKとPIO-USBがインストールされ、パッチが当たる)

あとは
6. patch -p0 < source-as-patchfile.diff でソースを展開
7. rebuild.sh 実行
   pico用とpico-W用のバイナリが以下にできます。
   build_examples/usb/pet/tinyusb_pet/host_hid_to_device_cdc_pet/tinyusb_pet_host_hid_to_device_cdc_pet.uf2
   build_w/usb/pet/tinyusb_pet/host_hid_to_device_cdc_pet/pocoW-tinyusb_pet_host_hid_to_device_cdc_pet.uf2

■Windows SDK の場合
1. Radpberry Pi Pico のSDKをインストール
   https://www.raspberrypi.com/news/raspberry-pi-pico-windows-installer/
   を参考に。
   以下、
    "C:\Program Files\Raspberry Pi\Pico SDK v1.5.1"
   にSDKがインストールされたとして進める。
2. C:\Program Files\Raspberry Pi\Pico SDK v1.5.1\pico-sdk\lib\tinyusb\hw\mcu\raspberry_pi\Pico-PIO-USB
   を、 https://github.com/sekigon-gonnoc/Pico-PIO-USB.git の最新版に入れ替える。
3. ここにある *.patch, *.diff を"C:\Program Files\Raspberry Pi\Pico SDK v1.5.1"へコピー
4. Pico - Developers Command Prompt を開く
5. Git for windows も入っていると思うので、
   "\Program Files\Git\usr\bin\cat.exe" *.patch *.diff | "\Program Files\Git\usr\bin\patch.exe" -p0
   でパッチを当てる。
6.あとはサンプルをリビルドする。

