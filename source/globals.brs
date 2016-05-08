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

Function GetGlobals()
	globals = GetGlobalAA()
	if globals.init = invalid then
		InitGlobals()
	end if
	return globals
	
End Function

Sub InitGlobals()

	globals = GetGlobalAA()
	
	globals.appInit = false

	globals.rokaResponse = false
	
	' ---------------- BEGIN CHECK BEFORE PACKAGING
	
	globals.localhost = false
	globals.saverTest = false
	globals.saver2Test = false
	globals.wipeonexit = false
	
	globals.usa = true
	
	globals.trial = false
	globals.expired = false
	globals.saver = false
 
	globals.cversion = "1.4.0"
		
	globals.features = {}
	'globals.features.music = globals.usa AND NOT globals.saver
	globals.features.music = false
	globals.features.locations = false
	globals.features.video = true
		
	' ---------------- END CHECK BEFORE PACKAGING
	if NOT globals.usa
		globals.cversion = globals.cversion + " NUS"
	end if
		
	if globals.trial
		globals.cversion = globals.cversion + " T"
	end if
	
	' prevent accidentally leaving the development server set
	devInfo = CreateObject("roDeviceInfo")
	uniqueId = devInfo.GetDeviceUniqueId()
	' safety check in case the localhost was left true
	if NOT ((uniqueId = "N0A09L015216") OR (uniqueId = "1GJ37E062368") OR (uniqueId = "12A18M065074") OR (uniqueId = "4124CG163257")) 
		globals.localhost = false
		globals.saverTest = false
		globals.saver2Test = false
		globals.wipeonexit = false
	end if

	globals.port = CreateObject("roMessagePort")
	
	globals.deviceInfo = {}
	globals.deviceInfo.version = devInfo.GetVersion()
	globals.deviceInfo.displayMode = devInfo.GetDisplayMode()
		
	'example "034.08E01185A".  The third through sixth characters are the major/minor version number ("4.08")
	globals.version = Val(Mid(globals.deviceInfo.version, 3, 4))
	major = Int(Val(Mid(globals.deviceInfo.version, 3, 1)))
    minor = Int(Val(Mid(globals.deviceInfo.version, 5, 2)))
    build = Int(Val(Mid(globals.deviceInfo.version, 8, 5)))
        
    globals.version = Val(Stri(major).Trim() + "." + Stri(minor).Trim())
    print "Version " + tostr(globals.version) + " (build " + tostr(build) + ")"
        
	globals.constants = {}
	globals.constants.sections = {}
	globals.constants.sections.default = "default"
	globals.constants.sections.feedfm = "feedfm"
	globals.constants.sections.instagram = "instagram"
	globals.constants.sections.feedfmStations = "feedfm/stations"
	globals.constants.sections.users = "users"
	globals.constants.sections.location = "location"
	globals.constants.sections.saver = "saver"
	globals.constants.sections.ga = "ga"
		
	globals.constants.keys = {}
	globals.constants.keys.trial_start = "trial_start"
	globals.constants.keys.upgrade_code = "upgrade_code"
		
	globals.rokagram = {}
	globals.instagram = {} 
	globals.ga = {}

	globals.ga.reqHash = {}
	globals.ga.reqCount = 0
	
	' defaults
	globals.ga.events = true
	globals.ga.screens = true
	globals.ga.social = true
	globals.ga.timing = true
	globals.ga.exceptions = true


	globals.rokagram.server = "https://rokagram-prod.appspot.com"
		
	if globals.localhost
		'globals.rokagram.server = "http://192.168.1.66:8888"
		' mac book pro
		globals.rokagram.server = "http://192.168.1.82:8888"
	end if
		
	hasBrowsed = RegRead("hasBrowsed", globals.constants.sections.default)
	globals.hasBrowsed = hasBrowsed <> invalid
	
	globals.trialDays = 15
	trialDaysReg = RegRead("trialDays", globals.constants.sections.default)
	if trialDaysReg <> invalid
		globals.trialDays = trialDaysReg.ToInt()
	end if
	
	globals.sslPatchDomain = "scontent.cdninstagram.com"
	sslPatchDomain = RegRead("sslPatchDomain", globals.constants.sections.default)
	if sslPatchDomain <> invalid
		globals.sslPatchDomain = sslPatchDomain
	end if
	
	
	client_id = RegRead("client_id", globals.constants.sections.instagram)
	if client_id = invalid
		globals.instagram.client_id = "c54578d4ca0142358b83561647b434cd"
	else 
		globals.instagram.client_id = client_id
	end if
	
		
	globals.init = true
	
	' put registry based init below to avoid recusive calls
	
    dispSize = devInfo.GetDisplaySize()
    globals.ga.sr = tostr(dispSize.w) + "x" + tostr(dispSize.h)
	ReadConfigSection(globals.ga, globals.constants.sections.ga)
	
	
	globals.instadaily = []
	
	globals.instadaily[0] = {}
	globals.instadaily[0].featuredTag = "SelfieSunday"
	globals.instadaily[0].description = "Embrace the modern self portrait"
		
	globals.instadaily[1] = {}
	globals.instadaily[1].featuredTag = "ManicMonday"
	globals.instadaily[1].description = "Duty calls, so booty crawls"
			
	globals.instadaily[2] = {}
	globals.instadaily[2].featuredTag = "TuesdayTransformation"
	globals.instadaily[2].description = "Before and after"
		
	globals.instadaily[3] = {}
	globals.instadaily[3].featuredTag = "WednesdayWisdom"
	globals.instadaily[3].description = "Mid-week wisdom"
			
	globals.instadaily[4] = {}
	globals.instadaily[4].featuredTag = "ThursdayThrowback"
	globals.instadaily[4].description = "Throwback Thursday"
		
	globals.instadaily[5] = {}
	globals.instadaily[5].featuredTag = "FridayFunday"
	globals.instadaily[5].description = "Gotta get down on Friday"
			
	globals.instadaily[6] = {}
	globals.instadaily[6].featuredTag = "Caturday"
	globals.instadaily[6].description = "Meow!"	

	globals.email = RegRead("email", globals.constants.sections.default)
	
	
	globals.feedfm = {}
	GetFeedFmClientId()
	
	globals.feedfm.placement = RegRead("placement", globals.constants.sections.feedfm)
	if globals.feedfm.placement = invalid
		globals.feedfm.placement = "10298"
	end if
	
	globals.feedfm.basicAuth = RegRead("basicAuth", globals.constants.sections.feedfm)
	if globals.feedfm.basicAuth = invalid
		globals.feedfm.basicAuth = "YjdiZDVhNDFiZjNiNjJhYWQzNTI2MjdmMzY4YjRjOTQyNDI4ZGQwYjpkZTNlZTQ4MWM5ODcyMjYyN2VjNWM5MGYwMWM3ZmU2ZmU3MTM2YjI5"
	end if
	
	globals.feedfm.station = RegRead("station", globals.constants.sections.feedfm)
	if globals.feedfm.station = invalid
		globals.feedfm.station = "9458"
	end if
	
	globals.feedfm.changeStation = RegReadBoolean("changeStation", globals.constants.sections.feedfm)
	
	if NOT globals.feedfm.changeStation
		print "can't change station, so reverting to defaults"
		globals.feedfm.placement = "10298"
		globals.feedfm.station = "9458"
	end if
	
	globals.feedfm.stations = []
	stationsSection = CreateObject("roRegistrySection", globals.constants.sections.feedfmStations)
	for each key in stationsSection.GetKeyList()
		globals.feedfm.stations.Push({station:key, description:stationsSection.Read()})
	next
	

	globals.radio = {}
	globals.radio.reqHash = {}
	globals.radio.state = ""
	globals.radio.diag_showing = false

	globals.logging = {}
	globals.logging.reqHash = {}
	globals.logging.reqCount = 0
	
	globals.radio.player = invalid
	
	globals.radio.asp = CreateAudioSpringBoardScreen()
	
	
	globals.screenStack = []
	
	globals.feeds = {}
	
	localhost_beauty_token = "1173959851.c54578d.7825ee8c8e9a49d9ac3f08b4e595f43a"
	rokagram_beauty_token = "1173959851.b13119e.be9711fcb60844b79c3caa32d18e33c2"
	
	beauty_token = rokagram_beauty_token
	if globals.localhost
		globals.feeds.beauty = {endpoint: "/users/self/feed", access_token:beauty_token}
	else
		globals.feeds.beauty = {endpoint: "/users/self/feed", access_token:beauty_token}
	
	end if
	
	globals.stats = {}
	globals.stats.clients = {}
		
End Sub

Sub RefreshRegistryBackedGlobals()
	
	globals.email = RegRead("email", globals.constants.sections.default)

	
End Sub

Sub SetFreeStation()
	SetFeedFmStation("9225")
End Sub

Function SetFeedFmStation(station)
	ret = false
	globals = GetGlobals()
	if globals.feedfm.station <> station
		LogRadioMessage("Changing feed.fm station from " + globals.feedfm.station + " to " + station)
		GaEvent("radio", "changeStation", globals.feedfm.station + "->" + station).PostAsync()
		globals.feedfm.station = station
		RegWrite("station", globals.feedfm.station, globals.constants.sections.feedfm)
		ret = true
	end if
	return ret
End Function
	
Sub ShowGlobals()
	printAA(GetGlobals())
End Sub

Function GetCurrentUser()
	return GetGlobals().current_user
End Function

Sub SetCurrentUser(user)
	GetGlobals().current_user = user
End Sub

Function AutoLogin()
	
	ret = GetCurrentUser()
	
	users = GetUsersList()

	if ret = invalid
		if users.Count() = 1
			SetCurrentUser(users[0])
			ret = GetCurrentUser()
		end if
	end if
	
	return ret
	
End Function

Sub AddCloseableScreen(screen)
	globals = GetGlobals()
	globals.screenStack.Push(screen)
	print "Added screeen, stack size: " + Stri(globals.screenStack.Count())
End Sub

Function GetFeedFmClientId()
	globals = GetGlobals()
	ret = globals.feedfm.client_id
	if ret = invalid then
		ret = RegRead("client_id", globals.constants.sections.feedfm)
		if ret <> invalid then
			SetFeedFmClientId(ret)
		end if
	end if
	return ret
End Function


Sub SetFeedFmClientId(client_id=invalid)
	globals = GetGlobals()	
	globals.feedfm.client_id = client_id
	if client_id <> invalid then
		RegWrite("client_id", globals.feedfm.client_id, globals.constants.sections.feedfm)
	else
		RegDelete("client_id", globals.constants.sections.feedfm)
	end if
End Sub

Function GetGlobalPort()
	return GetGlobals().port
End Function

Function GetServer()
	return GetGlobals().rokagram.server
End Function

Function GetClientId()
	return GetGlobals().instagram.client_id
End Function

Function GetUsersSectionName()
	return GetGlobals().constants.sections.users
End Function

Function GetLocationSectionName()
	return GetGlobals().constants.sections.location
End Function

Function GenerateGuid() As String
' Ex. {5EF8541E-C9F7-CFCD-4BD4-036AF6C145DA}
	Return "{" + GetRandomHexString(8) + "-" + GetRandomHexString(4) + "-" + GetRandomHexString(4) + "-" + GetRandomHexString(4) + "-" + GetRandomHexString(12) + "}"
End Function

Function GetRandomHexString(length As Integer) As String
	hexChars = "0123456789ABCDEF"
	hexString = ""
	For i = 1 to length
	    hexString = hexString + hexChars.Mid(Rnd(16) - 1, 1)
	Next
	Return hexString
End Function