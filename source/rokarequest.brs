' *********************************************************
' *********************************************************
' **
' **  Rokagram Channel
' **
' **  W. Pinkman, February 2014
' **
' **  Copyright (c) 2014 Fugue State, Inc., All Rights Reserved.
' **
' *********************************************************
' *********************************************************

Function CreateRokaRequest(port=invalid) As Object
	this = {
	
		xfer: CreateObject("roUrlTransfer"),
		port: port,
		SetMessagePort: function(port) : m.xfer.SetPort(port) : end function
		
		identity: invalid,
		
		GetToString: RokaRequestGetToString,
		SetUrl: function(url) : m.xfer.SetUrl(url) : return invalid : end function,
		
		SetUrl: function(url) : m.xfer.SetUrl(url) : return 0 : end function
		
		Close: function() : m.xfer.AsyncCancel() : m.xfer = invalid : return m.xfer : end function
	}

	globals = GetGlobals()
	
	' TODO: optimize this by using globals cached versions
	deviceInfo = CreateObject("roDeviceInfo")
	
	this.xfer.AddHeader("X-Rokagram-Reserved-Dev-Unique-Id", deviceInfo.GetDeviceUniqueId())
	
	this.xfer.AddHeader("X-Rokagram-Reserved-Firmware-Version", deviceInfo.GetVersion())
	this.xfer.AddHeader("X-Rokagram-Reserved-Channel-Version", globals.cversion)
	this.xfer.AddHeader("X-Rokagram-Reserved-Display-Mode", deviceInfo.GetDisplayMode())
	this.xfer.AddHeader("X-Rokagram-Reserved-Model", deviceInfo.GetModel())
	this.xfer.AddHeader("X-Rokagram-Reserved-Audio-Minutes", Stri(GetAudioMinutes()))
	
	users = RegReadUsers()
	usersHeader = ""
	for each user in users
		usersHeader = usersHeader + user + " "
	next
	this.xfer.AddHeader("X-Rokagram-Reserved-Users", usersHeader)
	
	currentUser = GetCurrentUser()
	if currentUser <> invalid then
		this.xfer.AddHeader("X-Rokagram-Reserved-CurrentUser", currentUser.id)
	end if
		
	if globals.email <> invalid
		this.xfer.AddHeader("X-Rokagram-Reserved-Email", globals.email)
	end if
	
	itemCode = RegRead(globals.constants.keys.upgrade_code, globals.constants.sections.default)
	if itemCode <> invalid
		this.xfer.AddHeader("X-Rokagram-Reserved-ItemCode", itemCode)
	end if
	
	if globals.trial
		this.xfer.AddHeader("X-Rokagram-Reserved-TrialDays", tostr(GetTrialDaysElapsed()))
	end if
	
	' allow for HTTPS
	this.xfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
	this.xfer.AddHeader("X-Roku-Reserved-Dev-Id", "")
	this.xfer.InitClientCertificates()
	
	if this.port = invalid then
		this.port = CreateObject("roMessagePort")
	end if
	this.xfer.SetPort(this.port)
	
	this.identity = this.xfer.GetIdentity()
	
	return this
End Function

Function RokaRequestGetToString(timeout=60)
	ret = invalid
	
	'm.xfer.SetUrl(m.url)
	m.xfer.AsyncGetToString()
	
	return WaitForHttp(timeout, m.port)
	
End Function


