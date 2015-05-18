' *********************************************************
' *********************************************************
' **
' **  Roku DVP Utilities Functions 
' **
' **  A. Wood, November 2009
' **
' **  Copyright (c) 2009 Anthony Wood. All Rights Reserved.
' **
' *********************************************************
' *********************************************************

'******************************************************
'Registry Helper Functions
'******************************************************

Function RegRead(key, section=invalid)
	ret = invalid
	if section = invalid then
		section  = GetDefaultSection()
	end if
	
    sec = CreateObject("roRegistrySection", section)
    if sec.Exists(key) then 
    	ret = sec.Read(key)
    end if
    
    return ret
    
End Function

Function RegWrite(key, val, section=invalid)
	if section = invalid then 
		section = GetDefaultSection()
	end if
	
	sec = CreateObject("roRegistrySection", section)
	regVal = invalid
	valType = type(val)
	if valType = "String" OR valType = "roString" then
		regVal =  val
	else if valType = "Integer" OR valType = "roInt" then
		regVal = tostr(val)
	end if
	
	if regVal <> invalid then
		sec.Write(key, regVal)
		sec.Flush() 'commit it
	else
		print "ERROR unsupported type: " + type(val)
		stop
	end if
End Function

Function RegReadBoolean(key, section=invalid) As Boolean
	return strtobool(RegRead(key, section))
End Function

Function RegWriteBoolean(key, val, section=invalid)
	valToWrite = "false"
	if isbool(val)
		if val
			valToWrite = "true"
		end if
		RegWrite(key, valToWrite, section)
	end if
End Function

Function GetDefaultSection()
	section = GetGlobals().constants.sections.default
	user = GetCurrentUser()
	if user <> invalid then
		section = GetUserSectionName(user.id) + "/" + GetGlobals().constants.sections.default
	end if
	
	return section
End Function

Function RegCondWrite(key, val, section=invalid)
	ret = false
	if RegRead(key,section) <> val then
		RegWrite(key,val, section)
		ret = true
	end if
	return ret
End Function

Function ReadScreenSaver(key)
	globals = GetGlobals()
	return RegRead(key, globals.constants.sections.saver)
End Function

Function WriteScreenSaver(key, val)
	globals = GetGlobals()
	if val <> invalid
		LogRegistryMessage(globals.constants.sections.saver + "/" + key + ": " + val)
		RegCondWrite(key, val, globals.constants.sections.saver)
	else
		LogRegistryMessage("deleting " + globals.constants.sections.saver + "/" + key)
		RegDelete(key, globals.constants.sections.saver)
	end if
End Function

Function ReadLocation()
	ret = invalid
	sec = CreateObject("roRegistrySection", GetLocationSectionName())
	for each key in sec.GetKeyList()
		if ret = invalid then
			ret = {}
		end if
		ret[key] = RegRead(key,GetLocationSectionName())
	next

	return ret
	
End Function


Function WriteLocation(location)
	ret = false
	
	location.Reset()
	while location.IsNext()
		key = location.Next()
		val = location[key]
		if RegCondWrite(key,val, GetLocationSectionName()) then
			ret = true
		end if
	end while
		
	return ret
	
End Function

Function WriteConfigSection(rokaResp, globalObj, sectionName)
	ret = false
	
	rokaResp.Reset()
	while rokaResp.IsNext()
		key = rokaResp.Next()
		val = rokaResp[key]
		json = FormatJson(val)
		
		'print "RegCondWrite("+key+","+ json+","+ sectionName+")"
		if RegCondWrite(key,json, sectionName) then
			ret = true
		end if
		
		globalObj[key] = val
		
	end while
		
	return ret

End Function

Sub ReadConfigSection(globalsObj, sectionName)
	
	sec = CreateObject("roRegistrySection", sectionName)
	for each key in sec.GetKeyList()
		json = RegRead(key, sectionName)
		'print "sec:" + sectionName + ", key:" + key + ", json:" + json
		globalsObj[key] = ParseJson(json)
	next
	
End Sub


Function WriteFeedfm(feedfm)
	ret = false
	section = GetGlobals().constants.sections.feedfm
	
	feedfm.Reset()
	while feedfm.IsNext()
		key = feedfm.Next()
		val = feedfm[key]
	
		RegCondWrite(key,val,section)
		
	end while
		
	ReadFeedfm()

return ret

End Function

Function ReadFeedfm()
	ret = GetGlobals().feedfm
	sec = CreateObject("roRegistrySection", GetGlobals().constants.sections.feedfm)
	for each key in sec.GetKeyList()
		ret[key] = RegRead(key, GetGlobals().constants.sections.feedfm)
	next
	
	return ret

End Function

Function RegDelete(key, section=invalid)
    if section = invalid then section = GetGlobals().constants.sections.default
    sec = CreateObject("roRegistrySection", section)
    sec.Delete(key)
    sec.Flush()
End Function

Function GetUserSectionName(id)
	return GetUsersSectionName() + "/" + id
End Function

Function RegReadUsers()
	sec = CreateObject("roRegistrySection", GetUsersSectionName())
	return sec.GetKeyList()
End Function

Function RegReadUser(userid)
	sec = CreateObject("roRegistrySection", GetUsersSectionName())
	if sec.Exists(userid) then
		
		return {userid:userid, access_token:RegRead(userid, GetUsersSectionName())}
	end if
	return invalid
End Function

Function RegCondWriteField(sectionName, entity, field)
	return RegCondWrite(field, entity[field], sectionName)
End Function

Function RegWriteUser(user)
	ret = false
	userid = user.id
	if user.access_token <> invalid
		RegCondWrite(userid, user.access_token, GetUsersSectionName())
		
		userSectionName = GetUserSectionName(userid)
		
		RegCondWriteField(userSectionName, user, "full_name") 
		RegCondWriteField(userSectionName, user, "profile_picture")
		RegCondWriteField(userSectionName, user, "username")
	end if
	
	return ret
	
End Function

Sub DeleteUser(userid)
	sec = CreateObject("roRegistrySection", GetUsersSectionName())
	sec.Delete(userid)
	sec.Flush() 
	reg = CreateObject("roRegistry")
	reg.Delete(GetUserSectionName(userid))
	reg.Flush()
	print "Deleted user " + userid
End Sub

Function DeleteUsers()
	sectionName =  GetUsersSectionName()
	reg = CreateObject("roRegistry")
	reg.Delete(sectionName)
	reg.Flush()
	
	print "Deleted " + sectionName
End Function

Function GetUsersList()
	
	userList  = []
	
	sec = CreateObject("roRegistrySection", GetUsersSectionName())
	keys = ""
	count = 0
	for each key in sec.GetKeyList()
		access_token = RegRead(key, GetUsersSectionName())
		user = {id:key, access_token:access_token}
		
		userSectionName =  GetUserSectionName(key)
		userSec = CreateObject("roRegistrySection", userSectionName)
		for each k in userSec.GetKeyList()
			user[k] = RegRead(k, userSectionName)
		next
		userList.Push(user)
	next
	
	return userList
	
End Function

Sub WipeRegistry()
	print "********** WIPING REGISTRY **************"
	reg = CreateObject("roRegistry")
	for each section in reg.GetSectionList()
		print "Deleting section " + section
		regSection = CreateObject("roRegistrySection",  section)
		for each key in regSection.GetKeyList()
			print "   " + key
		next
		reg.Delete(section)
	next
	reg.Flush()
End Sub

Sub ShowReg()
	reg = CreateObject("roRegistry")
	print "Registry "
	for each section in reg.GetSectionList()
		print "  Section " + section
		regSection = CreateObject("roRegistrySection",  section)
		for each key in regSection.GetKeyList()
			print "     " + Chr(34) + key + Chr(34) + " = " + regSection.Read(key)
		next
	next
End Sub

Function RegToXml()
		
	root = CreateObject("roXMLElement")
	root.SetName("registry")
	
	reg = CreateObject("roRegistry")
	
	for each section in reg.GetSectionList()
		sectionElement = root.AddElement("section")
		sectionElement.AddAttribute("name", section)
		
		regSection = CreateObject("roRegistrySection",  section)
		
		for each key in regSection.GetKeyList()
			entryElement = sectionElement.AddElement("entry")
			entryElement.AddAttribute("key", key)
			val = regSection.Read(key)
			if val <> invalid
				entryElement.AddAttribute("value", val)
			end if
		next
	next
	
	return root.GenXml(false)
	
End Function

Function SearchHistorySection(searchType) As String
	sectionName = searchType + "SearchHistory"
	currentUser = GetCurrentUser()
	if currentUser <> invalid then
		sectionName = GetUserSectionName(currentUser.id) + "/" + sectionName
	end if
	return sectionName
End Function

Function GetUserSettingsSection() As String
	sectionName = GetDefaultSection()
	currentUser = GetCurrentUser()
	if currentUser <> invalid then
		sectionName = GetUserSectionName(currentUser.id) + "/" + sectionName
	end if
	return sectionName

End Function

Sub ClearSearchHistory(searchType)
    reg = CreateObject("roRegistry")
    reg.Delete(SearchHistorySection(searchType))
    reg.Flush()
End Sub

Sub SaveUserToSearchHistory(currentUser, userData)
	regSection = CreateObject("roRegistrySection", SearchHistorySection(currentUser))
	if not regSection.Exists(userData.username) then
		if userData.userid <> invalid then
			print "Saving " + userData.username + ", userid:" + userData.userid + " to registry"
			regSection.Write(userData.username, userData.userid)
			regSection.Flush()
		else if userData.id <> invalid then
		print "Saving " + userData.username + ", id:" + userData.id + " to registry"
			regSection.Write(userData.username, userData.id)
			regSection.Flush()
		end if
	end if
End Sub



Function GetAudioSeconds() As Integer
	ret = 0
	regVal = RegRead("audio_seconds")
	if regVal <> invalid then
		ret = regVal
	end if
	return ret
End Function

Function GetAudioMinutes() As Integer
	return GetAudioSeconds() / 60
End Function

Sub IncrementAudioSeconds(seconds As Integer)
	RegCondWrite("audio_seconds", GetAudioSeconds() + seconds)
End Sub

Sub SetBreadcrumb(screen)
	currentUser = GetCurrentUser()
	if currentUser <> invalid then
		screen.SetBreadcrumbText("", currentUser.username)
		screen.SetBreadcrumbEnabled(true)
	else
		screen.SetBreadcrumbEnabled(false)
	end if
End Sub


'******************************************************
'Show error dialog with OK button
'******************************************************

Sub ShowErrorDialog(text As dynamic, title=invalid as dynamic)
    if not isstr(text) text = "Unspecified error"
    if not isstr(title) title = ""
    ShowDialog1Button(title, text, "Done")
End Sub

'******************************************************
'Show 1 button dialog
'Return: nothing
'******************************************************

Sub ShowDialog1Button(title As dynamic, text As dynamic, but1 As String)
    if not isstr(title) title = ""
    if not isstr(text) text = ""

    port = CreateObject("roMessagePort")
    dialog = CreateObject("roMessageDialog")
    dialog.SetMessagePort(port)

    dialog.SetTitle(title)
    dialog.SetText(text)
    dialog.AddButton(0, but1)
    dialog.Show()

    while true
        dlgMsg = WaitForEvent(0, dialog.GetMessagePort())

        if type(dlgMsg) = "roMessageDialogEvent"
            if dlgMsg.isScreenClosed()
                return
            else if dlgMsg.isButtonPressed()
                return
            endif
        endif
    end while
End Sub


Sub ShowScreenSaverSetDialog(title As dynamic)
	ShowDialog1Button("Screen Saver Set",  title + " will be used as source for screen saver. " + Chr(10) + Chr(10) + "You may need to navigate UP to get back to top level settings screen.", "Ok")
End Sub

'******************************************************
'Show 2 button dialog
'Return: 0=first button or screen closed, 1=second button
'******************************************************

Function ShowDialog2Buttons(title As dynamic, text As dynamic, but1 As String, but2 As String) As Integer
    if not isstr(title) title = ""
    if not isstr(text) text = ""
    	
    port = CreateObject("roMessagePort")
    dialog = CreateObject("roMessageDialog")
    dialog.SetMessagePort(port)

    dialog.SetTitle(title)
    dialog.SetText(text)
    dialog.AddButton(0, but1)
    dialog.AddButton(1, but2)
    dialog.Show()

    while true
        dlgMsg = WaitForEvent(0, dialog.GetMessagePort())

        if type(dlgMsg) = "roMessageDialogEvent"
            if dlgMsg.isScreenClosed()
                dialog = invalid
                return 0
            else if dlgMsg.isButtonPressed()
                dialog = invalid
                return dlgMsg.GetIndex()
            endif
        endif
    end while
End Function

' 0=Sunday
Function GetDayOfWeek(date As Object) As Integer
    daysFromEpoch = Int(date.AsSeconds() / 86400) + 1
    day = (daysFromEpoch Mod 7) - 4 'epoch is a Thursday (4)
    If day < 0 Then
        day = day + 7
    End If
    Return day
End Function


Function GetTrialDaysElapsed()
	globals = GetGlobals()
	ret = invalid
	
	dateTime = CreateObject("roDateTime")
	secondsNow% = dateTime.AsSeconds()
	secondsStart% = secondsNow%

	trialStart = RegRead(globals.constants.keys.trial_start,  globals.constants.sections.default)
	if trialStart = invalid
		RegWrite(globals.constants.keys.trial_start, Stri(secondsNow%).Trim(), globals.constants.sections.default)
	else
		secondsStart% = trialStart.ToInt()
	end if
	
	daysElapsed% = (secondsNow% - secondsStart%) / 86400%
	
	if globals.localhost
		print "WORKING IN MINUTES ELAPSED"
		daysElapsed% = (secondsNow% - secondsStart%) / 60%
	end if

	return daysElapsed%
End Function

Function GetMsgAction(msg)
	
	ret = "unknown"
		
	if msg.isListItemSelected()
		return "ListItemSelected"
	end if
	
	if msg.isScreenClosed()
		return "ScreenClosed"
	end if
	
	if msg.isListFocused()
		return "ListFocused"
	end if
	
	if msg.isListSelected()
		return "ListSelected"
	end if
	
	if msg.isListItemFocused()
		return "ListItemFocused"
	end if
	
	if msg.isButtonPressed()
		return "ButtonPressed"
	end if
	
	if msg.isPlaybackPosition()
		return "PlaybackPosition"
	end if
	
	if msg.isRemoteKeyPressed()
		return "RemoteKeyPressed"
	end if
	
	if msg.isRequestSucceeded()
		return "RequestSucceeded"
	end if
	
	if msg.isRequestFailed()
		return "RequestFailed"
	end if
	
	if msg.isRequestInterrupted()
		return "RequestInterrupted"
	end if
	
	if msg.isStatusMessage()
		return "StatusMessage"
	end if
	
	if msg.isPaused()
		return "Paused"
	end if
	
	if msg.isResumed()
		return "Resumed"
	end if
	
	if msg.isCleared()
		return "Cleared"
	end if
	
	if msg.isPartialResult()
		return "PartialResult"
	end if
	
	if msg.isFullResult()
		return "FullResult"
	end if
	
	if msg.isAdSelected()
		return "AdSelected"
	end if
	
	if msg.isPartialResult()
		return "PartialResult"
	end if
	
	'Since Firmware version 2.6:
	if msg.isStorageDeviceInserted()
		return "StorageDeviceInserted"
	end if
	
	if msg.isStorageDeviceRemoved()
		return "StorageDeviceRemoved"
	end if
	
	if msg.isStreamStarted()
		return "StreamStarted"
	end if

	'Since Firmware version 2.7:
	if msg.isListItemInfo()
		return "ListItemInfo"
	end if
	
	if msg.isButtonInfo()
		return "ButtonInfo"
	end if
	
	return ret
	
End Function

Function GetKeyPressName(msg)
	ret = ""
		
	if msg.isRemoteKeyPressed()
		index = msg.GetIndex()
		
		if index = 0
			return "keyBACK"
		end if
		if index = 2
			return "keyUP"
		end if
		if index = 3
			return "keyDOWN"
		end if
		if index = 4
			return "keyLEFT"
		end if
		if index = 5
			return "keyRIGHT"
		end if
		if index = 6
			return "keySELECT"
		end if
		if index = 7
			return "keyINSTANT_REPLAY"
		end if
		if index = 8
			return "keyREWIND"
		end if
		if index = 9
			return "keyFAST_FORWARD"
		end if
		if index = 10
			return "keyINFO"
		end if
		if index = 13
			return "keyPLAY"
		end if
		if index = 15
			return "keyENTER"
		end if
		if index = 17
			return "keyA"
		end if
		if index = 18
			return "keyB"
		end if
		if index = 22
			return "keyPLAY_ONLY"
		end if
		if index = 23
			return "keySTOP"
		end if
		
	end if
	
	return ret	
End Function


	