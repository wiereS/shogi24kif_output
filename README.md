# shogi24kif_output

将棋倶楽部24で対局した棋譜のコピーを自動的にローカルファイルに作成するスクリプト。

対局終わってから棋譜ボタンクリックして全選択して激指しに張り付けて保存して…な手間を省きたい人のために。

Wireshark での Lua スクリプトの勉強を兼ねて備忘録的に投稿。

Windows10 Pro 1709

Wireshark 2.4.5

で動作確認。


# 使い方
コマンドプロンプトで下記を実行。

tshark -X lua_script:"shogi24kif_output.lua"

対局が終わったと同時にデスクトップ上に作ったshogi24kifフォルダ内に棋譜が作成されます。
