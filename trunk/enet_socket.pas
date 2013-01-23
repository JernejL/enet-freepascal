unit enet_socket;


(**
 @file  win32.c
 @brief ENet Win32 system specific functions

 for freepascal
 1.3.6

 win32 => ENET_CALLBACK = _cdecl

 linux socket implementaion wasn't tested.
*)

interface

uses enet_consts , Sockets,
  {$ifdef MSWINDOWS}
  WinSock2
  {$else}
  oldlinux,
  unixsockets
  {$endif}
  ;

type
  pENetSocketSet = PFDSet;
  ENetSocketSet = TFDSet;

procedure ENET_SOCKETSET_EMPTY(var sockset : TFDSet);
procedure ENET_SOCKETSET_ADD(var sockset:TFDSet; socket:TSocket);
procedure ENET_SOCKETSET_REMOVE(var sockset:TFDSet; socket:TSocket);
function ENET_SOCKETSET_CHECK(var sockset:TFDSet; socket:TSocket):boolean;

function ENET_HOST_TO_NET_16(value:word):word;
function ENET_HOST_TO_NET_32(value:longword):longword;
function ENET_NET_TO_HOST_16(value:word):word;
function ENET_NET_TO_HOST_32(value:longword):longword;

function enet_initialize:integer;

procedure enet_deinitialize;

function enet_time_get:enet_uint32;

procedure enet_time_set (newTimeBase : enet_uint32);

function enet_address_set_host (address : pENetAddress; name : pchar):integer;

function enet_address_get_host_ip (address : pENetAddress; name : pchar ; nameLength : enet_size_t):integer;

function enet_address_get_host (address : pENetAddress; name : pchar; nameLength : enet_size_t):integer;

function enet_socket_create (Socktype : integer):ENetSocket;

function enet_socket_bind (socket : ENetSocket; const address : pENetAddress):integer;

function enet_socket_listen (socket: ENetSocket; backlog:integer):integer;

function enet_socketset_select (maxSocket:ENetSocket; readSet, writeSet:pENetSocketSet; timeout:enet_uint32):integer;

function enet_socket_set_option (socket : ENetSocket; option : (*ENetSocketOption*)integer; value : integer):integer;

function enet_socket_connect ( socket : ENetSocket;address :  pENetAddress):integer;

function enet_socket_accept (socket : ENetSocket; address :  pENetAddress):ENetSocket;

function enet_socket_shutdown (socket:ENetSocket; how : Integer { ENetSocketShutdown } ):Integer;

procedure enet_socket_destroy (socket : ENetSocket);

function enet_socket_send (socket : ENetSocket;
                  address : pENetAddress;
                  buffers : pENetBuffer;
                  bufferCount : enet_size_t ):integer;

function enet_socket_receive (socket : ENetSocket;
                     address : pENetAddress;
                     buffers : pENetBuffer;
                     bufferCount : enet_size_t):integer;

function enet_socket_wait (socket : ENetSocket; condition : penet_uint32; timeout : enet_uint32):integer;


implementation

uses
  sysutils,
  {$ifdef MSWINDOWS}
  mmsystem
  {$endif}
  ;

var
  // to do : cause this value, only one enet used in one executable.
  timeBase : enet_uint32 =0;
  versionRequested  : WORD;
  wsaData : TWSAData;

procedure ENET_SOCKETSET_EMPTY(var sockset:TFDSet);
begin
  FD_ZERO (sockset);
end;

procedure ENET_SOCKETSET_ADD(var sockset:TFDSet; socket:TSocket);
begin
  FD_SET (socket, sockset);
end;

procedure ENET_SOCKETSET_REMOVE(var sockset:TFDSet; socket:TSocket);
begin
  FD_CLR (socket, sockset);
end;

function ENET_SOCKETSET_CHECK(var sockset:TFDSet; socket:TSocket):boolean;
begin
  result := FD_ISSET (socket, sockset);
end;

function ENET_HOST_TO_NET_16(value:word):word;
begin
  result := (htons (value));
end;

function ENET_HOST_TO_NET_32(value:longword):longword;
begin
  result := (htonl (value));
end;

function ENET_NET_TO_HOST_16(value:word):word;
begin
  result := (ntohs (value));
end;

function ENET_NET_TO_HOST_32(value:longword):longword;
begin
  result := (ntohl (value));
end;

function enet_initialize:integer;
{$ifdef MSWINDOWS}
var
  versionRequested  : WORD;
  wsaData : TWSAData;
{$endif}
begin
  {$ifdef MSWINDOWS}
    versionRequested := $0101;


    if longbool(WSAStartup (versionRequested, wsaData)) then
       begin result := -1; exit; end;

    if (lo(wsaData.wVersion) <> 1) or
        (hi(wsaData.wVersion) <> 1) then
    begin
       WSACleanup;

       result := -1; exit;
    end;

    timeBeginPeriod (1);
  {$endif}

    result := 0;
end;

procedure enet_deinitialize;
begin
  {$ifdef MSWINDOWS}
    timeEndPeriod (1);

    WSACleanup ();
  {$endif}
end;

function enet_time_get:enet_uint32;
{$ifndef MSWINDOWS}
var
  tv : TTimeVal;
{$endif}
begin
  {$ifdef MSWINDOWS}
    Result := enet_uint32(timeGetTime - timeBase);
  {$else}
    GetTimeOfDay(tv);
    Result := tv.tv_sec * 1000 + tv.tv_usec div 1000 - timeBase;
  {$endif}
end;


procedure enet_time_set (newTimeBase : enet_uint32);
{$ifndef MSWINDOWS}
var
  tv : TTimeVal;
{$endif}
begin
  {$ifdef MSWINDOWS}
    timeBase := enet_uint32( timeGetTime - newTimeBase);
  {$else}
    GetTimeOfDay(tv);
    timeBase := tv.tv_sec * 1000 + tv.tv_usec div 1000 - newTimeBase;
  {$endif}
end;

function enet_address_set_host (address : pENetAddress; name : pchar):integer;
var
  hostEntry : PHostEnt;
  host : longword;
begin

    hostEntry :=gethostbyname (name);
    if (hostEntry = nil) or
        (hostEntry ^. h_addrtype <> AF_INET) then
    begin
       {$ifdef MSWINDOWS}
        host :=inet_addr (name);
        if (host = INADDR_NONE) then
            begin result := -1; exit; end;
        address ^. host :=host;
       {$else}
        address ^.host := StrToHostAddr(name);
        if address ^.host=0 then
            begin result:=-1; exit; end;
       {$endif}
        result := 0; exit;
    end;

    address ^. host := (penet_uint32(hostEntry^.h_addr_list^))^;

    result := 0;
end;

function enet_address_get_host_ip (address : pENetAddress; name : pchar ; nameLength : enet_size_t):integer;
var
  addr : pchar;
begin
    {$ifdef MSWINDOWS}
    addr :=inet_ntoa (pInAddr(@address ^. host)^);
    {$else}
    addr := PAnsiChar(HostAddrToStr(address^.host));
    if addr='' then addr:=nil;
    {$endif}
    if (addr = nil) then
        begin result := -1; exit; end;
    StrLCopy(name, addr, nameLength);
    result := 0;
end;

function enet_address_get_host (address : pENetAddress; name : pchar; nameLength : enet_size_t):integer;
var
  inadd : TInAddr;
  hostEntry : PHostEnt;
begin

    inadd.s_addr :=address ^. host;

    hostEntry :=gethostbyaddr (@inadd, sizeof (TInAddr), AF_INET);
    if (hostEntry = nil) then
      begin
         result := enet_address_get_host_ip (address, name, nameLength); exit;
      end;

    strlcopy (name, hostEntry ^. h_name, nameLength);

    result :=0;
end;

function enet_socket_bind (socket : ENetSocket; const address : pENetAddress):integer;
var
  sin : SOCKADDR_IN;
  retvalue : integer;
begin
    fillchar(sin, sizeof(SOCKADDR_IN), 0);

    sin.sin_family := AF_INET;

    if (address <> nil) then
    begin
       sin.sin_port := ENET_HOST_TO_NET_16 (address ^. port);
       sin.sin_addr.s_addr := address ^. host;
    end
    else
    begin
       sin.sin_port := 0;
       sin.sin_addr.s_addr := INADDR_ANY;
    end;

    retvalue := fpbind (socket,
                 @sin,
                 sizeof (SOCKADDR_IN));
    if retvalue = SOCKET_ERROR then
      result := -1
      else result := 0;
end;

function enet_socket_listen (socket: ENetSocket; backlog:integer):integer;
var
  backlogparam, retvalue : integer;
begin
  if backlog < 0 then
    backlogparam := SOMAXCONN
    else backlogparam := backlog;
  retvalue := fplisten (socket, backlogparam);
  if retvalue = SOCKET_ERROR then
    result := -1
    else result := 0;
end;

function enet_socket_create (Socktype : integer):ENetSocket;
var
  iSockType : integer;
begin
  if Socktype = ENET_SOCKET_TYPE_DATAGRAM then
    iSocktype := SOCK_DGRAM
    else iSocktype := SOCK_STREAM;
  result := fpsocket (PF_INET, iSocktype, 0);
end;

function enet_socket_set_option (socket : ENetSocket; option : (*ENetSocketOption*)integer; value : integer):integer;
var
  iResult : integer;
  nonBlocking : Longword;
begin
    iResult := -1;
    case (option) of

        ENET_SOCKOPT_NONBLOCK:
        begin
            nonBlocking := Longword(value);
            {$ifdef MSWINDOWS}
            iResult := ioctlsocket (socket, LongInt(FIONBIO), nonBlocking);
            {$else}
            iResult := ioctl (socket, FIONBIO, nonBlocking);
            {$endif}
        end;

        ENET_SOCKOPT_BROADCAST:
            iResult := fpsetsockopt (socket, SOL_SOCKET, SO_BROADCAST, @ value, sizeof (integer));

        ENET_SOCKOPT_REUSEADDR:
            iResult := fpsetsockopt (socket, SOL_SOCKET, SO_REUSEADDR, @ value, sizeof (integer));

        ENET_SOCKOPT_RCVBUF:
            iResult := fpsetsockopt (socket, SOL_SOCKET, SO_RCVBUF, @ value, sizeof (integer));

        ENET_SOCKOPT_SNDBUF:
            iResult := fpsetsockopt (socket, SOL_SOCKET, SO_SNDBUF, @ value, sizeof (integer));

        ENET_SOCKOPT_RCVTIMEO:
            iResult := fpsetsockopt (socket, SOL_SOCKET, SO_RCVTIMEO, @ value, sizeof (integer));

        ENET_SOCKOPT_SNDTIMEO:
            iResult := fpsetsockopt (socket, SOL_SOCKET, SO_SNDTIMEO, @ value, sizeof (integer));
    else ;
    end;
    if iResult = -1 then
      result := -1
             else result := 0;
end;


function enet_socket_connect ( socket : ENetSocket;address :  pENetAddress):integer;
var
  sin : sockaddr_in;
  retvalue : integer;
begin
    fillchar (sin,  sizeof (sockaddr_in), 0);

    sin.sin_family :=AF_INET;
    sin.sin_port :=ENET_HOST_TO_NET_16 (address ^. port);
    sin.sin_addr.s_addr := address ^. host;

    retvalue := fpconnect (socket, @ sin, sizeof (sockaddr_in));
    {$ifdef MSWINDOWS}
    if (retvalue = SOCKET_ERROR) and (WSAGetLastError <> WSAEWOULDBLOCK) then
       Result := -1
       else
         Result:=0;
    {$else}
    if (retvalue = -1) and (errno = EINPROGRESS) then
    begin
       Result:=0; exit;
    end;

    Result:=retvalue;
    {$endif}
end;

function enet_socket_accept (socket : ENetSocket; address :  pENetAddress):ENetSocket;
var
  sresult : TSocket;
  sin : sockaddr_in;
  sinLength : integer;
  p1 : Sockets.PSockAddr;
  p2 : PInteger;
begin
    sinLength :=sizeof (sockaddr_in);

    p1 := nil;
    p2 := nil;
    if address<>nil then begin
      p1 := @sin;
      p2 := @sinLength;
    end;
    sresult := fpaccept (socket,
                     p1,
                     p2);

    {$ifdef MSWINDOWS}
    if (sresult = INVALID_SOCKET) then
    {$else}
    if sresult = -1 then
    {$endif}
      begin result := ENET_SOCKET_NULL; exit; end;

    if (address <> nil) then
    begin
        address ^. host :=enet_uint32(sin.sin_addr.s_addr);
        address ^. port :=ENET_NET_TO_HOST_16 (sin.sin_port);
    end;

    result := sresult;
end;

function enet_socket_shutdown (socket:ENetSocket; how : Integer { ENetSocketShutdown } ):Integer;
begin
    Result := fpshutdown(socket,how);
    {$ifdef MSWINDOWS}
    if Result = SOCKET_ERROR then
       Result := -1
       else Result := 0;
    {$endif}
end;

procedure enet_socket_destroy (socket : ENetSocket);
begin
    if TSocket(socket) <> INVALID_SOCKET then
       closesocket(socket);
end;

function enet_socket_send (socket : ENetSocket;
                  address : pENetAddress;
                  buffers : pENetBuffer;
                  bufferCount : enet_size_t ):integer;
var
  sin : sockaddr_in;
  sentLength : longword;
{$ifdef MSWINDOWS}
  ipto : PSockAddr;
  iptolen : integer;
{$else}
  _msghdr : msghdr;
{$endif}
begin
    {$ifndef MSWINDOWS}
    FillChar(_msghdr,sizeof(msghdr),0);
    {$endif}

    if (address <> nil) then
    begin
        fillchar(sin,sizeof(sockaddr_in),0);
        sin.sin_family :=AF_INET;
        sin.sin_port :=ENET_HOST_TO_NET_16 (address ^. port);
        sin.sin_addr.s_addr :=address ^. host;
        {$ifndef MSWINDOWS}
        _msghdr.msg_name := @sin;
        _msghdr.msg_namelen := sizeof(sockaddr_in);
        {$endif}
    end;

    {$ifdef MSWINDOWS}
    ipto := nil;
    iptolen := 0;
    if address <> nil then begin
      ipto := @sin;
      iptolen := sizeof(sockaddr_in);
    end;
    if (wsaSendTo (socket,
                   Pointer(buffers),
                   longword(bufferCount),
                   sentLength,
                   0,
                   ipto,
                   iptolen,
                   nil,
                   nil) = SOCKET_ERROR) then
    begin
       if (WSAGetLastError () = WSAEWOULDBLOCK) then
         begin result := 0; exit; end;

       result := -1; exit;
    end;
    {$else}
    msgHdr.msg_iov = (struct iovec *) buffers;
    msgHdr.msg_iovlen = bufferCount;

    sentLength = sendmsg (socket, & msgHdr, MSG_NOSIGNAL);

    if (sentLength = -1) then
    begin
       if (errno = EWOULDBLOCK) then
         begin
            Result:=0; exit;
         end;

       Result:=-1; exit;
    end;
    {$endif}

    result := integer(sentLength);
end;

function enet_socket_receive (socket : ENetSocket;
                     address : pENetAddress;
                     buffers : pENetBuffer;
                     bufferCount : enet_size_t):integer;
var
  recvLength : longword;
  sin : SOCKADDR_IN;
  {$ifdef MSWINDOWS}
  sinLength : integer;
  flags : Longword;
  ipfrom : PSockAddr;
  ipfromlen : pinteger;
  {$else}
  _msghdr : msghdr;
  {$endif}
begin
    {$ifdef MSWINDOWS}
    sinLength :=sizeof (sockaddr_in);
    flags :=0;

    ipfrom := nil;
    ipfromlen := nil;
    if address <> nil then begin
      ipfrom := @sin;
      ipfromlen := @sinLength;
    end;
    if (WSARecvFrom (socket,
                     LPWSABUF(buffers),
                     longword(bufferCount),
                     recvLength,
                     flags,
                     ipfrom,
                     ipfromlen,
                     nil,
                     nil) = SOCKET_ERROR) then
    begin
       case (WSAGetLastError ()) of
       WSAEWOULDBLOCK,
       WSAECONNRESET:
          begin result := 0; exit; end;
       end;

       result := -1; exit;
    end;

    if (flags and MSG_PARTIAL)<>0 then
      begin result := -1; exit; end;
    {$else}
    fillchar(_msgHdr, sizeof(msghdr), 0);

    if (address <> nil) then
    begin
        _msgHdr.msg_name := @ sin;
        _msgHdr.msg_namelen := sizeof(sockaddr_in);
    end;

    _msgHdr.msg_iov := Pointer(buffers);
    _msgHdr.msg_iovlen := bufferCount;

    recvLength := recvmsg (socket, @ msgHdr, MSG_NOSIGNAL);

    if (recvLength = -1) then
    begin
       if (errno = EWOULDBLOCK) then
          begin
             Result:=0; exit;
          end;

       Result:=-1; exit;
    end;

{$ifdef _APPLE_}
    if (_msgHdr.msg_flags and MSG_TRUNC <> 0) then
       begin
          Result:=-1; exit;
       end;
{$endif}
    {$endif}

    if (address <> nil) then
    begin
        address ^. host :=enet_uint32( sin.sin_addr.s_addr);
        address ^. port :=ENET_NET_TO_HOST_16 (sin.sin_port);
    end;

    result := integer(recvLength);
end;


function enet_socketset_select (maxSocket:ENetSocket; readSet, writeSet:pENetSocketSet; timeout:enet_uint32):integer;
var
  timeVal : TTimeVal;
begin

    timeVal.tv_sec := timeout div 1000;
    timeVal.tv_usec := (timeout mod 1000) * 1000;

    result := select (maxSocket + 1, readSet, writeSet, nil, @ timeVal);
end;

function enet_socket_wait (socket : ENetSocket; condition : penet_uint32; timeout : enet_uint32):integer;
var
  readSet, writeSet : TFDSet;
  timeVal : TTimeVal;
  selectCount : integer;
begin
{    #ifdef HAS_POLL
        struct pollfd pollSocket;
        int pollCount;

        pollSocket.fd = socket;
        pollSocket.events = 0;

        if (* condition & ENET_SOCKET_WAIT_SEND)
          pollSocket.events |= POLLOUT;

        if (* condition & ENET_SOCKET_WAIT_RECEIVE)
          pollSocket.events |= POLLIN;

        pollCount = poll (& pollSocket, 1, timeout);

        if (pollCount < 0)
          return -1;

        * condition = ENET_SOCKET_WAIT_NONE;

        if (pollCount == 0)
          return 0;

        if (pollSocket.revents & POLLOUT)
          * condition |= ENET_SOCKET_WAIT_SEND;

        if (pollSocket.revents & POLLIN)
          * condition |= ENET_SOCKET_WAIT_RECEIVE;

        return 0;
    #else
}
    timeVal.tv_sec :=timeout div 1000;
    timeVal.tv_usec :=(timeout mod 1000) * 1000;

    FD_ZERO (readSet);
    FD_ZERO (writeSet);

    if (condition^ and ENET_SOCKET_WAIT_SEND)<>0 then
      FD_SET (socket, writeSet);

    if (condition^ and ENET_SOCKET_WAIT_RECEIVE)<>0 then
      FD_SET (socket, readSet);

    selectCount := select (socket + 1, @readSet, @writeSet, nil, @timeVal);

    if (selectCount < 0) then
      begin result := -1; exit; end;

    condition^ :=ENET_SOCKET_WAIT_NONE;

    if (selectCount = 0) then
      begin result := 0; exit; end;

    if (FD_ISSET (socket, writeSet)) then
      condition^  := condition^ or ENET_SOCKET_WAIT_SEND;

    if (FD_ISSET (socket, readSet)) then
      condition^ := condition^ or ENET_SOCKET_WAIT_RECEIVE;

    result := 0;
end;

end.
