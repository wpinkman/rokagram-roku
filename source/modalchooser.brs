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

Function ChooseTag(tags) 
	ret = invalid
	
	dialog = CreateObject("roMessageDialog")
	dialog.SetMessagePort(GetGlobalPort())
	
	dialog.SetTitle("Choose tag")
	
	btnMap = {}
	btnIndex = 0
	dialog.AddButton(btnIndex, "Close")
	btnIndex = btnIndex + 1
	for each tag in tags
		dialog.AddButton(btnIndex, tag)
		btnMap[Stri(btnIndex)] = tag
		btnIndex = btnIndex + 1
		
		if btnIndex > 9 then
		 	exit for
		end if
	next
	
	dialog.Show()
	
	while true 
	
		msg = wait(0, dialog.GetMessagePort())
		
		if type(msg)="roUrlEvent" then
			HandleFeedFmResponse(msg)
		else if type(msg)="roAudioPlayerEvent" then
			HandleAudioPlayerEvent(msg)
		else if type(msg) = "roMessageDialogEvent"
			if msg.isScreenClosed() 
				exit while
			else if msg.isButtonPressed()
				ret = btnMap[Stri(msg.GetIndex())]
				exit while
			end if
		end if
		
	end while
	
	dialog.Close()
	Sleep(100)
	
	return ret
	
End Function
