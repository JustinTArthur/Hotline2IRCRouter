; Hotline/IRC Chat Transfer Script
; Developed by Justin Arthur

;on *:START:%HLloggedIn = $null
on *:TEXT:>CCU(HLrelay;start):*:{ HLserver_CONNECT }

on *:TEXT:>CCU(HLrelay;end):*:{ HLserver_DISCONNECT }

on *:TEXT:*:#CCU:{
  if (%HLloggedIn == 1) { HLserver_SNDCHAT $nick text $strip($1-) }
}
on *:ACTION:*:#CCU:{
  if (%HLloggedIn == 1) { HLserver_SNDCHAT $nick action $strip($1-) }
}
on *:JOIN:#CCU:{
  if (%HLloggedIn == 1) { HLserver_SNDCHAT $nick join }
}
on *:PART:#CCU:{
  if (%HLloggedIn == 1) { HLserver_SNDCHAT $nick part }
}

on *:sockopen:CCU_HLserver:{
  %HLstepR = handshake
  %HLstepS = handshake
  %HLcurtranspos = 0
  %HLnewtrans = $true
  %HLclientTaskCount = 1
  echo -s Socket CCU_HLserver opened
  bset &currentstream 1 84 82 84 80 72 79 84 76 0 1 0 2
  sockwrite CCU_HLserver &currentstream
}

on *:sockwrite:CCU_HLserver:{
  ;echo -s %HLstepS sent.
  if (%HLstepS == Identification info) { %HLloggedIn = 1 }
}

alias bintesty {
  bset -t &sample 1 cat
  echo -s $bvar(&sample,0)
  bset &sample $bvar(&sample,0) 97
  echo -s $bvar(&sample,1,2).text
}

on *:sockread:CCU_HLserver:{
  ;echo -s Started reading something
  if ($sockerr > 0) { echo -s Error | return }
  :nextread
  if (%HLstepR == handshake) { sockread 8 &HLserverReply }
  if (%HLstepR == serverinfo) { sockread &HLserverInfo }
  ;if (%HLstepR == dunno1) { sockread &HLdunno | echo -s Dunno1 sucks }
  if (%HLstepR == ready) {
    sockread &Transaction
    if ($sockbr == 0) { return }
    ;echo -s SocketBuffer: $bvar(&Transaction,1,$bvar(&Transaction,0))
    if (%moreHLpacketsplease != $true) {
      hadd -b HLserver_PacketTable packetdata &Transaction
      HLserver_InitProc
      ;HLserver_InitProc $bvar(&Transaction,1,$bvar(&Transaction,0))
    }
    else {
      ;HLserver_InitProc %incompleteHLtransaction $bvar(&Transaction,1,$bvar(&Transaction,0)) | %moreHLpacketsplease = $false
      var hgetassign = $hget(HLserver_PacketTable,packetdata,&totalpacketdata)
      bcopy &totalpacketdata $calc($bvar(&totalpacketdata,0) + 1) &Transaction 1 -1
      hadd -b HLserver_PacketTable packetdata &totalpacketdata
      %moreHLpacketsplease = $false
      HLserver_InitProc
    }
  }

  ;if (%HLserverReply == $null) &HLserverReply = -
  if (%HLstepR == handshake) { if ($bvar(&HLserverReply,1-4).text == TRTP) { HLserver_LOGIN | return } }
  ;if (%HLstepR == serverinfo) {
  ;  echo -s Received Server Info: $bvar(&HLserverinfo,1,$bvar(&HLserverinfo,0)) 
  ;  if ($sockbr == 0) { %HLstepR = ready }
  ;}
  ;if (%HLstepR == dunno1) { echo -s Recieved dunno1: $bvar(&HLdunno,1,$bvar(&HLdunno,0)) | if ($sockbr == 0) { HLserver_IDENT } }
  ;if (%HLstepR == ready) { echo -s Recieved stuff. }
  goto nextread
}

alias HLserver_CONNECT {
  %HLserver_TARGETADDRESS = 216.12.68.96
  %HLserver_TARGETPORT = 5500
  %HLserver_TARGETCHANNEL = #CCU

  if ($hget(HLserver_PacketTable) != $null) { hfree HLserver_PacketTable }
  hmake HLserver_PacketTable 1

  if ($hget(HLserver_TransactionTable) != $null) { hfree HLserver_TransactionTable }
  hmake HLserver_TransactionTable 30
  hadd HLserver_TransactionTable position 0

  if ($hget(HLserver_ObjectTable) != $null) { hfree HLserver_ObjectTable }
  hmake HLserver_ObjectTable 40
  hadd HLserver_ObjectTable position 0

  sockclose CCU_HLserver
  sockopen CCU_HLserver %HLserver_TARGETADDRESS %HLserver_TARGETPORT
}

alias HLserver_DISCONNECT {
  sockclose CCU_HLserver
  %HLloggedIn = $null
  HLserver_ClearUsers
}

alias HLserver_LOGIN {
  %HLstepR = ready
  bset &currentstream 1 $&
    0 0 0 107 $&
    $DEC2DEClong(%HLclientTaskCount) $&
    0 0 0 0 $&
    0 0 0 27 0 0 0 27 $&
    0 3 $&
    0 105 0 3 150 141 156 $&
    0 106 0 8 133 222 156 151 158 139 222 133 $&
    0 160 0 2 0 184
  sockwrite CCU_HLserver &currentstream
  HLserver_MakeTask login
}

alias HLserver_IDENT {
  echo -s Identifying
  %HLstepS = Identification info
  %HLstepR = ready
  bset &currentstream 1 $&
    0 0 0 121 $&
    $DEC2DEClong(%HLclientTaskCount) $&
    0 0 0 0 $&
    0 0 0 22 0 0 0 22 $&
    0 3 $&
    0 102 0 4 35 67 67 85 $&
    0 104 0 2 0 220 $&
    0 113 0 2 0 3
  sockwrite CCU_HLserver &currentstream
  HLserver_MakeTask ident
}

alias HLserver_REQUESTUSERS {
  bset &currentstream 1 $&
    0 0 1 44 $&
    $DEC2DEClong(%HLclientTaskCount) $&
    0 0 0 0 $&
    0 0 0 2 0 0 0 2 $&
    0 0
  sockwrite CCU_HLserver &currentstream
  HLserver_MakeTask userlist
}

alias HLserver_SNDCHAT {
  %HLstepS = Chat message
  ;echo -s Starting to send message
  if ($2 == join) { %Msg2Snd = <<< $1 has joined #CCU on the $network IRC network. >>> }
  if ($2 == part) { %Msg2Snd = <<< $1 has left #CCU on the $network network. >>> }
  if ($2 == text) { %Msg2Snd = < $+ $1 $+ > $3- }
  if ($2 == action) { %Msg2Snd = *** $1 $3- }
  bset -t &Msg2Snd 1 %Msg2Snd
  unset %Msg2Snd
  bset &currentstream 1 $&
    0 0 $&
    0 105 $&
    $DEC2DEClong(%HLclientTaskCount) $&
    0 0 0 0 $&
    $DEC2DEClong($calc($bvar(&Msg2Snd,0) + 6)) $&
    $DEC2DEClong($calc($bvar(&Msg2Snd,0) + 6)) $&
    0 1 $&
    0 101 $&
    $DEC2DECshort($bvar(&Msg2Snd,0))
  ;$& $bvar(&Msg2Snd,1,$bvar(&Msg2Snd,0))
  bcopy &currentstream $calc($bvar(&currentstream,0) + 1) &Msg2Snd 1 -1
  ;echo -s Message packet: $bvar(&currentstream,1-$bvar(&currentstream,0))	
  sockwrite CCU_HLserver &currentstream
  HLserver_MakeTask chatmsg
}

alias HLserver_InitProc {
  ;bset &fullpacket 1 $1-
  var %hgetassign = $hget(HLserver_PacketTable,packetdata,&fullpacket)
  hdel HLserver_PacketTable packetdata
  ;echo -s InitProc receives: $bvar(&fullpacket,1,$bvar(&fullpacket,0))
  var %fullpacketpos = 1
  var %thisTransactionStart = 1
  var %thisTransactionPos = 1
  var %thisTransactionEnd
  var %thisTransactionType
  var %thisTransDatalength
  while ( %fullpacketpos <= $bvar(&fullpacket,0) ) {
    ;echo -s thisTrasactionPos = %thisTransactionPos
    ;echo -s fullpacketpos = %fullpacketpos
    ;echo -s $bvar(&fullpacket,%fullpacketpos,1)
    ;echo -s bset &thistransaction %thistransactionpos $bvar(&fullpacket,%fullpacketpos,1)
    bset &thistransaction %thistransactionpos $bvar(&fullpacket,%fullpacketpos,1)
    if ((%thistransactionpos >= 13) && (%thistransactionpos <= 20)) {
      bset &thisTransDatalength $calc(%thisTransactionPos - 12) $bvar(&fullpacket,%fullpacketpos,1)
    }
    inc %fullpacketpos
    if (%thisTransactionPos == 20) {
      if ($bvar(&thisTransDatalength,1,4) != $bvar(&thisTransDatalength,5,4)) { echo -s Protocol is no longer recognizable; disconnecting from %HLserver_TARGETADDRESS. | HLserver_DISCONNECT }
      else {
        %thisTransDatalength = $DEClong2DEC($bvar(&thisTransDatalength,1,4))
        %thisTransactionEnd = $calc((%thisTransactionStart - 1) + 20 + %thisTransDatalength)
        ; The transaction seems valid, let's see whether the packet contains the whole thing:
        if (%thisTransactionEnd <= $bvar(&fullpacket,0)) { 
          ; Sweet, it does! Let's send it off.
          ;bset &thisTransaction 1 $bvar(&fullpacket,%thisTransactionStart,$calc(20 + %thisTransDatalength))
          bcopy &thisTransaction 1 &fullpacket %thisTransactionStart $calc(20 + %thisTransDatalength)
          ; Allright, we've finally compiled a full valid transaction (we hope at least) to send off, before we do that, let's prepare for the next transaction.
          %thisTransactionStart = $calc(%thisTransactionEnd + 1)
          %fullpacketpos = %thisTransactionStart
        }
        else {
          %moreHLpacketsplease = $true
          bcopy &incompleteHLtransaction 1 &fullpacket %thisTransactionStart -1
          hadd -b HLserver_PacketTable packetdata &incompleteHLtransaction
        }
        ;else { %moreHLpacketsplease = $true | %incompleteHLtransaction = $bvar(&fullpacket,%thisTransactionStart,$calc($bvar(&fullpacket,0) - %thisTransactionStart)) }
        ; Allright, we've FINALLY got ourselves a nifty transaction here. Let's figure out what the hell it is and send it where it needs to go.
        %thisTransactionType = $DECshort2DEC($bvar(&thisTransaction,3,2))
        ;echo -s Transaction Type: %thisTransactionType
        if (%thisTransactionType == 0) { HLserver_ReplyProc $bvar(&thisTransaction,1,$bvar(&thisTransaction,0)) }
        elseif (%thisTransactionType == 106) {
          hadd -b HLserver_TransactionTable transaction $+ $hget(HLserver_TransactionTable,position) &thisTransaction
          ;HLserver_ChatTransProc $bvar(&thisTransaction,1,$bvar(&thisTransaction,0))
          HLserver_ChatTransProc $hget(HLserver_TransactionTable,position)
        }
        elseif (%thisTransactionType == 109) { HLserver_IDENT }
        elseif (%thisTransactionType == 301) { HLserver_UserchangeTransProc $bvar(&thisTransaction,1,$bvar(&thisTransaction,0)) }
        elseif (%thisTransactionType == 302) { HLserver_UserleaveTransProc $bvar(&thisTransaction,1,$bvar(&thisTransaction,0)) }
        elseif (%thisTransactionType == 355) {
          hadd -b HLserver_TransactionTable transaction $+ $hget(HLserver_TransactionTable,position) &thisTransaction
          ;HLserver_AdminBcastProc $bvar(&thisTransaction,1,$bvar(&thisTransaction,0))
          HLserver_AdminBcastProc $hget(HLserver_TransactionTable,position)
        }
        %thisTransactionPos = 0
      }
    }
    inc %thisTransactionPos
  }
  return
}

alias HLserver_ReplyProc {
  bset &transaction 1 $1-
  var %task = $DEClong2DEC($bvar(&transaction,5,4))
  var %tasktype = [ % $+ [ HLtask $+ [ %task ] ] ]
  var %numobjects = $DECshort2DEC($bvar(&transaction,21,2))
  var %curobjectnum = 1
  var %curdatapos = 23
  if (%tasktype == login) {
    HLserver_ClearUsers
    while (%curobjectnum <= %numobjects) {
      var %curobjecttype = $DECshort2DEC($bvar(&transaction,%curdatapos,2))
      var %curobjectlen = $calc($DECshort2DEC($bvar(&transaction,$calc(%curdatapos + 2),2)) + 4)
      var %parttogoto = $calc(%curdatapos + (%curobjectlen - 1))
      if ( %curobjecttype == 162 ) { 
        bcopy &servernameobject 1 &transaction %curdatapos $calc(%parttogoto - (%curdatapos - 1))
        hadd -b HLserver_ObjectTable object $+ $hget(HLserver_ObjectTable,position) &servernameobject
        ;%HLservername = $HLserver_ObjectProc($bvar(&transaction,%curdatapos,$calc(%parttogoto - (%curdatapos - 1))))
        %HLservername = $HLserver_ObjectProc($hget(HLserver_ObjectTable,position))
        msg %HLserver_TARGETCHANNEL 5,15This channel is now connected to  $+ %HLservername $+  using the hotline protocol!
      }
      %curdatapos = $calc(%curdatapos + %curobjectlen)
      inc %curobjectnum
    }
  }
  if (%tasktype == ident) { echo -s Server recieved identification information. | %HLloggedIn = 1 | HLserver_RequestUsers }
  if (%tasktype == userlist) {
    HLserver_ClearUsers
    while (%curobjectnum <= %numobjects) {
      var %curobjecttype = $DECshort2DEC($bvar(&transaction,%curdatapos,2))
      var %curobjectlen = $calc($DECshort2DEC($bvar(&transaction,$calc(%curdatapos + 2),2)) + 4)
      var %parttogoto = $calc(%curdatapos + (%curobjectlen - 1))
      if ( %curobjecttype == 300 ) {
        bcopy &userlistobject 1 &transaction %curdatapos $calc(%parttogoto - (%curdatapos - 1))
        hadd -b HLserver_ObjectTable object $+ $hget(HLserver_ObjectTable,position) &userlistobject
        ;HLserver_ObjectProc $bvar(&transaction,%curdatapos,$calc(%parttogoto - (%curdatapos - 1)))
        HLserver_ObjectProc $hget(HLserver_ObjectTable,position)
      }
      else { echo -s Bad userlist; disconnecting. | HLserver_DISCONNECT }
      %curdatapos = $calc(%curdatapos + %curobjectlen)
      inc %curobjectnum
    }
  }
  unset % $+ [ HLtask $+ [ %task ] ]
}

alias HLserver_ChatTransProc {
  hinc HLserver_TransactionTable position
  ;bset &transaction 1 $1-
  var %hgetassign = $hget(HLserver_TransactionTable,transaction $+ $1,&transaction)
  hdel HLserver_TransactionTable transaction $+ $1
  var %curobjectnum = 1
  var %curdatapos = 23
  var %curobjectlen
  var %curobjectpos
  ;echo -s Receieved current script transaction number $1
  var %numobjects = $DECshort2DEC($bvar(&transaction,21,2))
  ;echo -s Transaction %HLcurtranspos has %numobjects object(s) in it. and an ID long of $bvar(&transaction,1,4)
  while (%curobjectnum <= %numobjects) {
    %curobjectlen = $calc($DECshort2DEC($bvar(&transaction,$calc(%curdatapos + 2),2)) + 4)
    var %parttogoto = $calc(%curdatapos + (%curobjectlen - 1))
    bcopy &messageobject 1 &transaction %curdatapos $calc(%parttogoto - (%curdatapos - 1))
    hadd -b HLserver_ObjectTable object $+ $hget(HLserver_ObjectTable,position) &messageobject
    ;var %chatmessage = $HLserver_ObjectProc($bvar(&transaction,%curdatapos,$calc(%parttogoto - (%curdatapos - 1))))
    var %chatmessage = $HLserver_ObjectProc($hget(HLserver_ObjectTable,position))
    if ( $left(%chatmessage,5) != #CCU:) { msg %HLserver_TARGETCHANNEL 5,15HL1: %chatmessage }
    %curdatapos = $calc(%curdatapos + %curobjectlen)
    inc %curobjectnum
  }
}

alias HLserver_UserchangeTransProc {
  bset &transaction 1 $1-
  ;echo -s Binary transaction = $bvar(&transaction,1,$bvar(&transaction,0))
  var %curobjectnum = 1
  var %curdatapos = 23
  var %curobjectlen
  var %curobjectpos
  var %curobjecttype
  ;echo -s Receieved current script transaction number $1
  ;echo -s Object short = $gettok(%transaction,21-22,32)
  var %numobjects = $DECshort2DEC($bvar(&transaction,21,2))
  ;echo -s Transaction %HLcurtranspos has %numobjects object(s) in it. and an ID long of $gettok(%transaction,1-4,32)
  var %whiletimes = 1
  while (%curobjectnum <= %numobjects) {
    %curobjecttype = $DECshort2DEC($bvar(&transaction,%curdatapos,2))
    ;%curobjectlen = $calc($DECshort2DEC($gettok(%transaction,$calc( %curdatapos + 2 ),32) $gettok(%transaction,$calc( %curdatapos + 3 ),32))+4)
    %curobjectlen = $calc($DECshort2DEC($bvar(&transaction,$calc(%curdatapos + 2),2)) + 4)
    ;echo -s Length of current object = %curobjectlen
    ;echo -s Type of current object = %curobjecttype
    var %parttogoto = $calc(%curdatapos + (%curobjectlen - 1))
    ;echo -s curdatapos = %curdatapos
    ;echo -s partogoto = %parttogoto
    if ( %curobjecttype == 103 ) {
      bcopy &socketidobject 1 &transaction %curdatapos $calc(%parttogoto - (%curdatapos - 1))
      hadd -b HLserver_ObjectTable object $+ $hget(HLserver_ObjectTable,position) &socketidobject
      ;var %socket = $HLserver_ObjectProc($bvar(&transaction,%curdatapos,$calc(%parttogoto - (%curdatapos - 1))))
      var %socket = $HLserver_ObjectProc($hget(HLserver_ObjectTable,position))
    }
    elseif (%curobjecttype == 104) {
      bcopy &usericonobject 1 &transaction %curdatapos $calc(%parttogoto - (%curdatapos - 1))
      hadd -b HLserver_ObjectTable object $+ $hget(HLserver_ObjectTable,position) &usericonobject
      ;var %icon = $HLserver_ObjectProc($bvar(&transaction,%curdatapos,$calc(%parttogoto - (%curdatapos - 1))))
      var %icon = $HLserver_ObjectProc($hget(HLserver_ObjectTable,position))
    }
    elseif (%curobjecttype == 112) {
      bcopy &userstatusobject 1 &transaction %curdatapos $calc(%parttogoto - (%curdatapos - 1))
      hadd -b HLserver_ObjectTable object $+ $hget(HLserver_ObjectTable,position) &userstatusobject
      ;var %status = $HLserver_ObjectProc($bvar(&transaction,%curdatapos,$calc(%parttogoto - (%curdatapos - 1))))
      var %status = $HLserver_ObjectProc($hget(HLserver_ObjectTable,position))
    }
    elseif (%curobjecttype == 102) {
      bcopy &nickobject 1 &transaction %curdatapos $calc(%parttogoto - (%curdatapos - 1))
      hadd -b HLserver_ObjectTable object $+ $hget(HLserver_ObjectTable,position) &nickobject
      var %nick = $HLserver_ObjectProc($hget(HLserver_ObjectTable,position))
      ;var %nick = $HLserver_ObjectProc($bvar(&transaction,%curdatapos,$calc(%parttogoto - (%curdatapos - 1))))
    }
    %curdatapos = $calc(%curdatapos + %curobjectlen)
    inc %curobjectnum
    if (%whiletimes >= 7) { return }
    inc %whiletimes
  }
  if ($readini(HLconnected.ini,n,%socket,stat) == $null) {
    ;echo -s New user!
    writeini HLconnected.ini %socket nick %nick
    writeini HLconnected.ini %socket stat %status
    writeini HLconnected.ini %socket icon %icon
    if ( (%nick != PleaseLoginProperly) || ($strip($HLserver_StatusProc(%status)) != a regular user ]°[) ) { msg %HLserver_TARGETCHANNEL 5,15HL1: 3***  $+ %nick $+  is now connected as $HLserver_StatusProc(%status) $+ . }
  }
  else {
    if ($readini(HLconnected.ini,n,%socket,nick) != %nick) {
      msg %HLserver_TARGETCHANNEL 5,15HL1: 3***  $+ $readini(HLconnected.ini,n,%socket,nick) $+  is now known as  $+ %nick $+ .
      writeini HLconnected.ini %socket nick %nick
    }
    if ($HLserver_StatusProc($readini(HLconnected.ini,n,%socket,stat)) != $HLserver_StatusProc(%status)) {
      msg %HLserver_TARGETCHANNEL 5,15HL1: 3***  $+ %nick $+  is now $HLserver_StatusProc(%status) $+ .
      writeini HLconnected.ini %socket stat %status
    }
    if ($readini(HLconnected.ini,n,%socket,icon) != %icon) {
      writeini HLconnected.ini %socket icon %icon
    }
  }
  ;if (%nick != PleaseLoginProperly) { msg %HLserver_TARGETCHANNEL %nick is now connected to the hotline server as $HLserverStatusProc(%status) on socket %socket $+ . }
  if (%HLcurtranspos >= 5) { %HLcurtranspos = 0 }
  inc %HLcurtranspos
  %HLnewtrans = true
}

alias HLserver_UserleaveTransProc {
  bset &transaction 1 $1-
  var %curobjectnum = 1
  var %curdatapos = 23
  var %curobjectlen
  var %curobjectpos
  ;echo -s Receieved current script transaction number $1
  var %numobjects = $DECshort2DEC($bvar(&transaction,21,2))
  ;echo -s Transaction %HLcurtranspos has %numobjects object(s) in it. and an ID long of $bvar(&transaction,1,4)
  while (%curobjectnum <= %numobjects) {
    %curobjectlen = $calc($DECshort2DEC($bvar(&transaction,$calc(%curdatapos + 2),2)) + 4)
    ;echo -s Length of current object = %curobjectlen
    var %parttogoto = $calc(%curdatapos + (%curobjectlen - 1))
    bcopy &usersocketobject 1 &transaction %curdatapos $calc(%parttogoto - (%curdatapos - 1))
    hadd -b HLserver_ObjectTable object $+ $hget(HLserver_ObjectTable,position) &usersocketobject
    ;var %leavingsock = $HLserver_ObjectProc($bvar(&transaction,%curdatapos,$calc(%parttogoto - (%curdatapos - 1))))
    var %leavingsock = $HLserver_ObjectProc($hget(HLserver_ObjectTable,position))
    var %leavinguser = $readini(HLconnected.ini,n,%leavingsock,nick)
    var %leavingstat = $readini(HLconnected.ini,n,%leavingsock,stat)
    if ( ($readini(HLconnected.ini,n,%leavingsock,stat) != $null) && ( (%leavinguser != PleaseLoginProperly) || ($left($strip($HLserver_StatusProc(%leavingstat)),14) != a regular user) ) ) { msg %HLserver_TARGETCHANNEL 5,15HL1: 3***  $+ %leavinguser $+  has disconnected. }
    %curdatapos = $calc(%curdatapos + %curobjectlen)
    remini HLconnected.ini %leavingsock
    inc %curobjectnum
  }
  if (%HLcurtranspos >= 5) { %HLcurtranspos = 0 }
  inc %HLcurtranspos
  %HLnewtrans = true
}

alias HLserver_AdminBcastProc {
  hinc HLserver_TransactionTable position
  ;bset &transaction 1 $1-
  var hgetassign = $hget(HLserver_TransactionTable,transaction $+ $1,&transaction)
  hdel HLserver_TransactionTable transaction $+ $1
  var %curobjectnum = 1
  var %curdatapos = 23
  var %curobjectlen
  var %curobjectpos
  var %curobjecttype
  var %numobjects = $DECshort2DEC($bvar(&transaction,21,2))
  ;var %whiletimes = 1
  while (%curobjectnum <= %numobjects) {
    %curobjecttype = $DECshort2DEC($bvar(&transaction,%curdatapos,2))
    %curobjectlen = $calc($DECshort2DEC($bvar(&transaction,$calc(%curdatapos + 2),2)) + 4)
    ;echo -s Length of current object = %curobjectlen
    ;echo -s Type of current object = %curobjecttype
    var %parttogoto = $calc(%curdatapos + (%curobjectlen - 1))
    ;echo -s curdatapos = %curdatapos
    ;echo -s partogoto = %parttogoto
    if ( %curobjecttype == 102 ) {
      bcopy &usernickobject 1 &transaction %curdatapos $calc(%parttogoto - (%curdatapos - 1))
      hadd -b HLserver_ObjectTable object $+ $hget(HLserver_ObjectTable,position) &usernickobject
      ;var %nick = $HLserver_ObjectProc($bvar(&transaction,%curdatapos,$calc(%parttogoto - (%curdatapos - 1))))
      var %nick = $HLserver_ObjectProc($hget(HLserver_ObjectTable,position))
    }
    elseif ( %curobjecttype == 101 ) {
      bcopy &bcastmsgobject 1 &transaction %curdatapos $calc(%parttogoto - (%curdatapos - 1))
      hadd -b HLserver_ObjectTable object $+ $hget(HLserver_ObjectTable,position) &bcastmsgobject
      ;var %message = $HLserver_ObjectProc($bvar(&transaction,%curdatapos,$calc(%parttogoto - (%curdatapos - 1))))
      var %message = $HLserver_ObjectProc($hget(HLserver_ObjectTable,position))
    }
    %curdatapos = $calc(%curdatapos + %curobjectlen)
    inc %curobjectnum
    ;if (%whiletimes >= 7) { return }
    ;inc %whiletimes
  }
  notice %HLserver_TARGETCHANNEL 5,15HL1: Administrative broadcast from  $+ %nick $+ : %message 
}

alias HLserver_ObjectProc {
  hinc HLserver_ObjectTable position
  ;bunset &object
  ;bset &object 1 $1-
  var %hgetassign = $hget(HLserver_ObjectTable,object $+ $1,&object)
  hdel HLserver_ObjectTable object $+ $1
  var %objecttype = $DECshort2DEC($bvar(&object,1,2))
  ;echo -s Object Type: %objecttype
  if ( (%objecttype == 100) || (%objecttype == 102) || (%objecttype == 162) ) { return $bvar(&object,5,$calc($bvar(&object,0)-4)).text }
  elseif (%objecttype == 101) { return $replace($bvar(&object,5,$calc($bvar(&object,0)-4)).text,$chr(13),$chr(32)) }
  elseif ( ( %objecttype == 103 ) || ( %objecttype == 104 ) ) { return $DECshort2DEC($bvar(&object,5,2)) }
  elseif (%objecttype == 112) { return $DECshort2DEC($bvar(&object,5,2)) }
  elseif (%objecttype == 300) {
    var %socket = $DECshort2DEC($bvar(&object,5,2))
    var %icon = $DECshort2DEC($bvar(&object,7,2))
    var %status = $DECshort2DEC($bvar(&object,9,2))
    var %nick = $bvar(&object,13,$calc($bvar(&object,0) - 12)).text
    writeini HLconnected.ini %socket nick %nick
    writeini HLconnected.ini %socket stat %status
    writeini HLconnected.ini %socket icon %icon
  }
}

alias HLserver_StatusProc {
  var %status = $1
  var %color = $readini(HLrouterSettings.ini,%status,clr)
  var %usertypeicon = $readini(HLrouterSettings.ini,%status,icn)
  if ( (%color == b) && (%usertypeicon == y) ) { return a regular user 1]0,7°1[3 }
  elseif ( (%color == r) && (%usertypeicon == r) ) { return a 2nd Class Administrator 4]0,4°4[3 }
  elseif ( (%color == r) && (%usertypeicon == b) ) { return a 1st Class Administrator / CCU Official 4]0,1°4[3 }
  elseif ( (%color == b) && (%usertypeicon == g) ) { return a user with no privelages 1]0,3°1[3 }
  else { return an unknown user type }
}

alias HLserver_MakeTask {
  if ($1 != chatmsg) { set [ % $+ [ HLtask $+ [ %HLclientTaskCount ] ] ] $1 }
  inc %HLclientTaskCount
  if (%HLclientTaskCount >= 65536) { set %HLclientTaskCount 0 }
}

alias HLserver_ClearUsers {
  if ($isfile(HLconnected.ini)) { remove HLconnected.ini }
}

alias HEX2DEC_couplate {
  var %pos = 1
  var %coupledout
  while (%pos <= $len( $1- )) {
    %coupledout = %coupledout $base($mid($1-,%pos,2),16,10)
    inc %pos 2
  }
  return %coupledout
}

alias DEClong2DEC {
  if ($numtok($1,32) == 4) {
    return $base( $+ $&
      $base($gettok($1,1,32),10,16,2) $+ $&
      $base($gettok($1,2,32),10,16,2) $+ $&
      $base($gettok($1,3,32),10,16,2) $+ $&
      $base($gettok($1,4,32),10,16,2),16,10)
  }
}

alias DECshort2DEC {
  if ($numtok($1,32) == 2) {
    return $base( $+ $&
      $base($gettok($1,1,32),10,16,2) $+ $&
      $base($gettok($1,2,32),10,16,2),16,10)
  }
}

alias DEC2DECshort {
  var %hex = $base($1,10,16,4)
  return $base($left(%hex,2),16,10) $base($right(%hex,2),16,10)
}

alias DEC2DEClong {
  var %hex = $base($1,10,16,8)
  return $base($mid(%hex,1,2),16,10) $base($mid(%hex,3,2),16,10) $base($mid(%hex,5,2),16,10) $base($mid(%hex,7,2),16,10)
}

on *:sockclose:CCU_HLserver:{
  echo -s Connection to Hotline server closed.
  HLserver_ClearUsers
  %HLloggedIn = $null
  HLserver_CONNECT
}
