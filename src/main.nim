import parseopt, httpclient, uri, times, net, tables, strutils, json
import xEncode

var
  baseUrl = "https://gw.buaa.edu.cn/cgi-bin/"
  callbackName = "autologin"
  cookieUrl = "https://gw.buaa.edu.cn/index_1.html?ad_check=1"

proc help(err: int) =
  echo "Usage: buaalogin [-u:username] [-p:password] login/logout/status/detect"
  quit(err)

proc getResponse(reqType: string; params: Table[string, string]): JsonNode =
  var reqUrl = baseUrl
  var p = params
  case reqType
  of "challenge":
    reqUrl &= "get_challenge"
  of "login", "logout":
    reqUrl &= "srun_portal"
  of "status":
    reqUrl &= "rad_user_info"
  p["callback"] = callbackName
  p["_"] = intToStr(int(getTime().toUnixFloat()*1000))
  p["ad_check"] = "1"
  var q: seq[string]
  for k, v in p.pairs:
    q.add(encodeQuery({k:v}))

  reqUrl &= "?" & join(q,"&")
  let client = newHttpClient(maxRedirects=0, sslContext=newContext(verifyMode=CVerifyNone))
  client.headers = newHttpHeaders({"Host": "gw.buaa.edu.cn",
      "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:96.0) Gecko/20100101 Firefox/96.0",
      "Accept": "text/javascript, application/javascript, application/ecmascript, application/x-ecmascript, */*; q=0.01",
      "Referer": "https://gw.buaa.edu.cn/srun_portal_pc?ac_id=1&theme=buaa&url=www.buaa.edu.cn",
      "cookie": "lang=zh-CN; AD_VALUE=5c0e4450; cookie=0"
    })
  
  let resp = client.get(cookieUrl)
  # echo resp.headers
  if resp.headers.hasKey("set-cookie"):
    var str = ""
    for value in resp.headers.table["set-cookie"]:
      let data = value.split(";")[0]
      str.add(data & ";")
    client.headers["cookie"] = str & " cookie=0"
  # echo client.headers
  let client2 = newHttpClient(sslContext=newContext(verifyMode=CVerifyNone))
  client2.headers = client.headers
  let body = client2.getContent(reqUrl)
  result = parseJson(body[len(callbackName)+1 .. ^2])

proc getLoginParams(username, password, ac_id, ip, enc_ver, n, Type, os, name, double_stack, token: string): Table[string, string] =
  var infoJson = %*
    {
      "username": username,
      "password": password,
      "ip": ip,
      "acid": ac_id,
      "enc_ver": enc_ver
    }
  let info = getEncodedInfo($infoJson, token)
  let pwd = getEncodedPassword(password, token)

  let chkstr = token & username & token & pwd & token & ac_id & token & ip & token & n & token & Type & token & info
  let chksum = getEncodedChkstr(chkstr)

  result = {
    "action": "login",
    "username": username,
    "password": "{MD5}" & pwd,
    "ac_id": ac_id,
    "ip": ip,
    "chksum": chksum,
    "info": info,
    "n": n,
    "type": Type,
    "double_stack": double_stack
    }.toTable

proc login(username, password: string) =
  var
    ac_id        = "1"
    enc_ver      = "srun_bx1"
    n            = "200"
    Type         = "1"
    os           = "Windows 10"
    name         = "Windows"
    double_stack = "0"

  let challenge = getResponse("challenge", {"username": username}.toTable)
  let token = challenge["challenge"].getStr()
  let ip = challenge["client_ip"].getStr()

  let params = getLoginParams(username, password, ac_id, ip, enc_ver, n, Type, os, name, double_stack, token)
  let loginResponse = getResponse("login", params)
  let res = loginResponse["error"].getStr()

  if res == "ok":
    echo loginResponse["suc_msg"].getStr()
  else:
    let error_msg = loginResponse["error_msg"].getStr()
    echo res & ", " & error_msg

proc logout() =
  let stat = getResponse("status", initTable[string, string]())
  let ip = stat["client_ip"].getStr()
  let user = stat["user_name"].getStr()
  let params = {"action": "logout", "username": user, "ac_id": "1", "ip": ip}.toTable
  let resp = getResponse("logout", params)
  let res = resp["error"].getStr()
  if res == "ok":
    echo resp["suc_msg"].getStr()
  else:
    let error_msg = resp["error_msg"].getStr()
    echo res & ", " & error_msg

proc status() =
  let resp = getResponse("status", initTable[string, string]())
  echo pretty(resp)

proc detect(user, pwd: string) =
  let stat = getResponse("status", initTable[string, string]())
  let err = stat["error"].getStr()
  if err == "ok":
    echo "User is already online. skip"
  else:
    echo "not online, logging in"
    login(user, pwd)

proc main() =
  var p = initOptParser()
  var
    action: string
    user: string
    pwd: string

  for kind, key, val in p.getopt():
    case kind
    of cmdArgument:
      action = key
    of cmdLongOption, cmdShortOption:
      case key
      of "user", "u": user = val
      of "pwd", "p": pwd = val
      of "help", "h": help(QuitSuccess)
    of cmdEnd: assert(false)

  case action
  of "login":
    login(user, pwd)
  of "logout":
    logout()
  of "status":
    status()
  of "detect":
    detect(user, pwd)
  of "":
    help(QuitFailure)

when isMainModule:
  main()