
--[[
shogi24kif_output - Wireshark Lua script which outputs kif files from captured packets of ShogiClub24
Copyright (C) 2018  wiereS

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
--]]


-- 棋譜を書き込むフォルダのパス。 以下では %USERPROFILE%\Desktop\shogi24kif にしてる。
userprofile = os.getenv("USERPROFILE")
folderpath = userprofile.."\\Desktop\\shogi24kif\\"


shogi24_proto = Proto("shogi24_proto","Shogi24 Protocol (description)")

function shogi24_proto.dissector(buffer, pinfo, tree)
    pinfo.cols.protocol = "Shogi24 PROTO"

    local buflen = buffer:len() -- shogi24_proto のデータサイズ取得

    if buflen > 100 then 
        local byte_array = buffer(0, buflen):bytes() -- buffer からByteArrayを取得。
        local byte_rawstr = byte_array:raw()  -- ByteArrayの数字をそのまま文字列に変換。（int[]→stringへの変換みたいな感じ？）
        local byte_hexstr = tostring( byte_array )  -- ByteArrayの数字をHex表記の文字列に変換。

        -- bufferに文字列"StartGameCommand" があれば、対局情報をcsaファイルに書き込み。tmpfile.raw へ csaファイルのファイル名を書き込み。
        local a1, b1 = string.find(byte_hexstr , "537461727447616D65436F6D6D616E64")  -- "StartGameCommand"
        if a1 ~= nil then
            local a2, b2 = string.find(byte_hexstr , "73720028636F6D2E73686F6769646F6A6F2E73686F67692E636F6D6D6F6E2E47616D65436F6E646974696F6E") -- "sr.(com.shogidojo.shogi.common.GameCondition"
            local p1name = buffer((a1-1)/2 + 246, (a2-1)/2 - (a1-1)/2 - 246):string()
            local p2name = buffer((b2-1)/2 + 64, buflen - (b2-1)/2 - 64 +1 ):string()

            -- 対局開始時の時間(start_ts)の取得
            local pinfo_time = os.date("*t", tostring(pinfo.abs_ts))
            local start_y = string.format("%04d",pinfo_time.year)
            local start_m = string.format("%02d",pinfo_time.month)
            local start_d = string.format("%02d",pinfo_time.day)
            local start_H = string.format("%02d",pinfo_time.hour)
            local start_M = string.format("%02d",pinfo_time.min)
            local start_ts = start_y..start_m..start_d..start_H..start_M

            --保存するkifufile（csaファイル）の名前  
            local filename = start_ts.."_"..p1name.."_vs_"..p2name..".csa"

            -- kifufile名を記憶するためのファイル。
            local tmpfile = io.open(folderpath.."tmpfile.raw", "w")
            tmpfile:write(filename)
            tmpfile:close()

            local kifufile = io.open(folderpath..filename, "w")
            kifufile:write("N+"..p1name.."\n")
            kifufile:write("N-"..p2name.."\n")           
            kifufile:write("$START_TIME:"..start_y.."/"..start_m.."/"..start_d.." "..start_H..":"..start_M.."\n")
            kifufile:write("$EVENT:レーティング対局室(早指し2)\n")
            kifufile:write("P1-KY-KE-GI-KI-OU-KI-GI-KE-KY\n")
            kifufile:write("P2 * -HI *  *  *  *  * -KA * \n")
            kifufile:write("P3-FU-FU-FU-FU-FU-FU-FU-FU-FU\n")
            kifufile:write("P4 *  *  *  *  *  *  *  *  * \n")
            kifufile:write("P5 *  *  *  *  *  *  *  *  * \n")
            kifufile:write("P6 *  *  *  *  *  *  *  *  * \n")
            kifufile:write("P7+FU+FU+FU+FU+FU+FU+FU+FU+FU\n")
            kifufile:write("P8 * +KA *  *  *  *  * +HI * \n")
            kifufile:write("P9+KY+KE+GI+KI+OU+KI+GI+KE+KY\n")
            kifufile:write("\'先手番\n")
            kifufile:write("+\n")

            kifufile:close()
        end

        -- bufferに文字列"promotionxp" があれば、 kifufileへ棋譜符号を書き込み。
        local prom1, prom2 = string.find(byte_hexstr , "70726F6D6F74696F6E7870")  -- "promotionxp"
        if prom1 ~= nil then
            -- buffer から指し手の符号情報を読み込み
            local tmpbuf = buffer((prom2-1)/2+1,9)
            local first_move = tmpbuf(0,1):le_uint() -- 1なら先手、0なら後手
            local piece = tmpbuf(1,1):le_uint() -- 駒種を定義する数値(int)に変換
            local last_posi_x = tmpbuf(2,1):le_uint()  --駒のもと居た筋。駒台から打ったら0
            local last_posi_y = tmpbuf(3,1):le_uint()
            local move_to_x = tmpbuf(4,1):le_uint()  --駒の移動した先の筋。
            local move_to_y = tmpbuf(5,1):le_uint()
            local movenum = tmpbuf(6,2):uint()
            local promo = tmpbuf(8,1):uint()
            local used_time = buffer((prom2-1)/2+1+80,2):uint()
            piece_list = {"OU","HI","KA","KI","GI","KE","KY","FU"}
            piece_promo_list = {"","RY","UM","","NG","NK","NY","TO"}

            -- 棋譜を書き込むファイル名（writefile_name）を"tmpfile.raw"から取得
            local readfile = io.open(folderpath.."tmpfile.raw", "r")     
            local writefile_name = readfile:read("*a")
            readfile:close() 
            
            ---- 棋譜の書き込み。ここから-----
            local kifufile = io.open(folderpath..writefile_name, "a")
            if first_move == 1 then 
                kifufile:write("+")
            else 
                kifufile:write("-")
            end
            kifufile:write(tostring(last_posi_x)..tostring(last_posi_y))
            kifufile:write(tostring(move_to_x)..tostring(move_to_y))
            -- 成り駒判定 
            if promo == 1 then
                kifufile:write(piece_promo_list[piece])
            else
                kifufile:write(piece_list[piece])
            end
            kifufile:write("\n".."T"..tostring(used_time).."\n")
            kifufile:close()
            ---- 棋譜の書き込み。ここまで-----
        end
        
        -- bufferに文字列"EndGameCommand" があれば、 kifufileへ投了を書き込み。     
        local endstr1, endstr2 = string.find(byte_hexstr , "456E6447616D65436F6D6D616E64")  -- "EndGameCommand"
        if endstr1 ~= nil then
            -- 棋譜を書き込むファイル名（writefile_name）を"tmpfile.raw"から取得
            local readfile = io.open(folderpath.."tmpfile.raw", "r")     
            local writefile_name = readfile:read("*a")
            readfile:close() 
            ---- 棋譜の書き込み。ここから-----
            local kifufile = io.open(folderpath..writefile_name, "a")
            kifufile:write("%TORYO\n")
            kifufile:close()
            ---- 棋譜の書き込み。ここまで-----
            os.remove(folderpath.."tmpfile.raw")
        end

    end

end

-- TCP port 9999 をshogi24_protoと解釈する
tcp_table = DissectorTable.get("tcp.port")
tcp_table:add(9999, shogi24_proto)


