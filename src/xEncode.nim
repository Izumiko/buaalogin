import hmac, std/sha1, strutils

proc toString(str: seq[byte]): string =
  result = newStringOfCap(len(str))
  for ch in str:
    add(result, char(ch))

proc xEncode(info, token: string): string =
  proc s(a: string; b: bool): seq[uint32] =
    let c = len(a)
    var v = newSeq[uint32](0)
    for i in countup(0,int((c+3)/4)-1):
      v.add(0)
    for i in countup(0,c-1,4):
      for j in countup(0,3):
        if j+i >= c:
          break
        v[i shr 2] = v[i shr 2] or ((uint32(a[i+j]) shl uint(8*j)))
    if b:
      v.add(uint32(c))
    result = v
  proc l(a: openArray[uint32], b: bool): string =
    let d = len(a)
    var c = (d - 1) shl 2
    if b:
      let m = a[d-1]
      if int(m) < c-3 or int(m) > c:
        result = ""
        return
      c = int(m)
    var tmp: seq[byte]
    for i in countup(0,d-1):
      tmp.add(byte(a[i] and 0xff))
      tmp.add(byte(a[i] shr 8 and 0xff))
      tmp.add(byte(a[i] shr 16 and 0xff))
      tmp.add(byte(a[i] shr 24 and 0xff))
    let str = toString(tmp)
    if b:
      result = str[0..c]
    result = str

  if len(info) == 0:
    result = ""
  else:
    echo info
    var v = s(info,true)
    var k = s(token, false)
    var n = len(v) - 1
    var z = v[n]
    var y = v[0]
    var d = 0'u32
    for q in countdown(int(6+52/(n+1)),1):
      d += 0x9E3779B9'u32
      var e = (d shr 2) and 3
      for p in countup(0,n):
        if p == n:
          y = v[0]
        else:
          y = v[p+1]
        var m = (z shr 5) xor (y shl 2)
        m += (y shr 3) xor (z shl 4) xor (d xor y)
        m += k[(p and 3) xor int(e)] xor z
        v[p] += m
        z = v[p]
    result = l(v,false)


proc trashBase64(t: string): string =
  let base64N = "LVoJPiCN2R8G90yg+hmFHuacZ1OWMnrsSTXkYpUq/3dlbfKwv6xztjI7DeBE45QA"
  let a = len(t)
  var ln: int = int(a / 3) * 4
  if ln mod 3 != 0:
    ln += 4
  var u = newSeq[byte](0)
  for i in countup(0,ln-1):
    u.add(0)
  let r = byte('=')
  var ui = 0
  for o in countup(0,a-1,3):
    var p = newSeq[byte](3)
    p[2] = byte(t[o])
    if o+1 < a:
      p[1] = byte(t[o+1])
    else:
      p[1] = 0
    if o+2 < a:
      p[0] = byte(t[o+2])
    else:
      p[0] = 0
    var h = int(p[2]) shl 16 or int(p[1]) shl 8 or int(p[0])
    for i in countup(0,3):
      if o*8+i*6 > a*8:
        u[ui] = r
      else:
        u[ui] = byte(base64N[h shr uint(6*(3-i)) and 0x3F])
      ui += 1
  result = toString(u)

proc getEncodedInfo*(info, token: string): string =
  result = "{SRBX1}" & trashBase64(xEncode(info, token))

proc getEncodedPassword*(password, token: string): string =
  let md5 = hmac_md5(token, password)
  result = toHex(md5)

proc getEncodedChkstr*(chkstr: string): string =
  result = toLowerAscii($(secureHash(chkstr)))