class LinebotController < ApplicationController
  require 'line/bot' # gem 'line-bot-api'
  require "json"     # gem 'json'(使わなくても良さそう?)
  

  # callbackアクションのCSRF(クロスサイトリクエストフォージェリ)への対応
  protect_from_forgery :except => [:callback]

  def client
    @client ||= Line::Bot::Client.new { |config|      #lineの送信画面からのリクエストのアクション
      config.channel_secret = ENV["LINE_CHANNEL_SECRET"]
      config.channel_token = ENV["LINE_CHANNEL_TOKEN"]
    }
  end

  def callback
    body = request.body.read

    signature = request.env['HTTP_X_LINE_SIGNATURE']
    unless client.validate_signature(body, signature)
      error 400 do 'Bad Request' end
    end

    events = client.parse_events_from(body)

    #ここでlineに送られたイベントを検出している
    # messageのtext: に指定すると、返信する文字を決定することができる
    #event.message['text']で送られたメッセージを取得することができる
    events.each { |event|
      if event.message['text'] != nil   # messageが空ではなかった時
        place = event.message['text']  #ここでLINEで送った文章を取得
        latitude = event.message['latitude']
        longitude = event.message['longitude']
        result = `curl -X GET https://api.gnavi.co.jp/RestSearchAPI/v3/?keyid=78d2d49f3aa8747a6cc03da01cf41bdd\\&category_s=RSFST08008\\&latitude=#{latitude}\\&longitude=#{longitude}` #ここでぐるなびAPIを叩く
      else
        latitude = event.message['latitude']
        longitude = event.message['longitude']
        puts event.message['latitude']
        puts event.message['longitude']
        puts event.message['latitude'].class
        result = `curl -X GET https://api.gnavi.co.jp/RestSearchAPI/v3/?keyid=78d2d49f3aa8747a6cc03da01cf41bdd\\&category_s=RSFST08008\\&latitude=#{latitude}\\&longitude=#{longitude}`#ここでぐるなびAPIを叩く
      end
      require "json"
      hash_result = JSON.parse result      #レスポンスが文字列なのでhashにパースする
      shops = hash_result["rest"]          #ここでお店情報が入った配列となる
      shop = shops.sample                  #任意のものを一個選ぶ
      puts shop
      
      #店の情報
      url = shop["url_mobile"]             #サイトのURLを送る
      shop_name = shop["name"]             #店の名前
      category = shop["category"]          #カテゴリー
      open_time = shop["opentime"]         #空いている時間
      holiday = shop["holiday"]            #定休日

      if open_time.class != String         #空いている時間と定休日の二つは空白の時にHashで返ってくるので、文字列に直そうとするとエラーになる。そのため、クラスによる場合分け。
        open_time = ""
     end
     if holiday.class != String
        holiday = ""
      end

      response = "こちらのお店はいかがですか？" + "\n"+"【店名】" + shop_name + "\n" + "【カテゴリー】" + category + "\n" + "【営業時間と定休日】" + open_time + "\n" + holiday + "\n" + url
       case event 
      when Line::Bot::Event::Message
        case event.type                                #case~when文で条件分岐
        when Line::Bot::Event::MessageType::Text
          uri = URI.parse("https://api.a3rt.recruit-tech.co.jp/talk/v1/smalltalk") #テキスト型のリクエストが送られた際の返信
          http = Net::HTTP.new(uri.host, uri.port)       #net::~構文でhttpの情報を得る。
  
          http.use_ssl = true
          http.verify_mode = OpenSSL::SSL::VERIFY_NONE
  
          req = Net::HTTP::Post.new(uri.path)            #net::~構文で情報を得る。
          req.set_form_data({'apikey' => ENV["Talk_Key"], 'query' => event.message['text']})
  
          res = http.request(req)                        #リクエストメソッドを使用
          result = JSON.parse(res.body)                  #レスポンスはjson型なのでパースする。
          message = {
            type: 'text',
            text: result["results"][0]["reply"]
          }
          client.reply_message(event['replyToken'], message)
        

        when Line::Bot::Event::MessageType::Location                    #位置情報のリクエストが送られた際の返信
          message = {
            type: 'text',
            text: response
          }
          client.reply_message(event['replyToken'], message)
        
      end
      end
    } 

    head :ok
  end
end