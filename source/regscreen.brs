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

Function CreateRegistrationScreen() As Object
	this = {
	
		screen: CreateObject("roCodeRegistrationScreen"),
		rokaRequest: CreateRokaRequest(),
		port: CreateObject("roMessagePort"),
		url: GetServer() + "/api/roku",
		Run: CodeRegistrationScreenRun,
		screenName: "linking",
		
		Close: function() : m.rokaRequest.Close() : m.screen.Close() : m.port = invalid : m.screen = invalid : return m.screen : end function
		
	}

	this.screen.SetMessagePort(this.port)
	
	'this.screen.SetTitle("[Registration screen title]")
    this.screen.AddParagraph("You may link one or more Instagram accounts to this device. If you don't have an account, you can create one with the Instagram mobile app.")
    this.screen.AddFocalText(" ", "spacing-dense")
    this.screen.AddFocalText("From your computer or mobile device,", "spacing-dense")
    this.screen.AddFocalText("go to http://rokagram.com", "spacing-dense")
    this.screen.AddFocalText("and enter this code:", "spacing-dense")

    this.screen.SetRegistrationCode("retreiving code...")
    this.screen.AddParagraph("This page will automatically update when linking is complete.")
    this.screen.AddButton(0, "Get a new code")
    this.screen.AddButton(1, "Back")
    
	return this
	
End Function

Function CodeRegistrationScreenRun()
	
	m.screen.Show()
	GaScreenView(m.screenName).PostAsync()
	
	closed = false
	m.rokaRequest.SetUrl(m.url)

	loopCount = 0
	
	while loopCount < 60 * 5
	
		json = m.rokaRequest.GetToString()
		
		if json <> invalid
			print "loopCount:" + Stri(loopCount) + ", resp:" + json
		else
			print "loopCount:" + Stri(loopCount) + "NO RESPONSE"
		end if
		
		response = ParseJson(json)
		
		if loopCount = 0
			msg = ""
			if response <> invalid AND response.code <> invalid
				msg = "Code: " + response.code
			end if
			LogRegScreenMessage(msg)
		end if
		
		if response <> invalid then
		
			if response.code <> invalid then
				m.screen.SetRegistrationCode(response.code)
				m.rokaRequest.SetUrl(m.url + "?code=" + response.code)
			end if
			
			if response.linked then
				RegWriteUser(response.user)
				LogRegScreenMessage("Linked to: " + response.user.username)
				showCongratulationsScreen(response.user,m)
				return 0
			end if
		else
			print "ERROR, something wrong with response from server"
		end if
	
		msg = WaitForEvent(1000, m.port)
		
		if msg <> invalid then
			print "MESSAGE: " + type(msg)
	        if type(msg) = "roCodeRegistrationScreenEvent"
	            if msg.isScreenClosed()
	                closed = true
	                exit while
	            elseif msg.isButtonPressed()
	                if msg.GetIndex() = 0
	                    m.screen.SetRegistrationCode("retrieving code...")
	                    m.rokaRequest.SetUrl(m.url)
	                    loopCount = 0
	                endif
	                if msg.GetIndex() = 1 then
	                	exit while
	                end if
	            endif
	        endif
		end if
		
		loopCount = loopCount + 1
		
	end while
		
	if not closed then	
		m.Close()
	end if
	
	print "EXITING REGSCREEN"
	return 0
	
End Function

'******************************************************
'Show congratulations screen
'******************************************************
Sub showCongratulationsScreen(user, regScreen)
    port = CreateObject("roMessagePort")
    screen = CreateObject("roParagraphScreen")
    screen.SetMessagePort(port)

    screen.AddHeaderText("Congratulations")
    screen.AddParagraph("You have successfully linked this Roku player to your account")
    if user.profile_picture <> invalid
    	screen.AddGraphic(user.profile_picture)
    end if
    screen.AddButton(1, "Follow getrokagram")
    screen.AddButton(2, "Continue")
    screen.Show()
    
    GaScreenView("congrats").PostAsync()
    
    regScreen.Close()

    while true
    	print "showCongratulationsScreen: waiting"
        msg = WaitForEvent(0, port)

        if type(msg) = "roParagraphScreenEvent"
            if msg.isScreenClosed()
            	GaEvent(type(msg), GetMsgAction(msg)).PostAsync()
                print "Screen closed"
                exit while                
            else if msg.isButtonPressed()
                if msg.GetIndex() = 1
                	getrokagramId = "501866943"
					followRequest = CreateInstaRequest()
					followRequest.access_token = user.access_token
					followRequest.endpoint = "/users/" + getrokagramId + "/relationship"
					followRequest.AddBodyParam("action", "follow")
					msg = followRequest.PostWithStatus("Following ...")
					if msg <> invalid
						GaSocial("follow", getrokagramId).PostAsync()
					end if
                end if
                exit while
            else
                print "Unknown event: "; msg.GetType(); " msg: "; msg.GetMessage()
                exit while
            endif
        endif
    end while
    print "EXITING CONGRATS"
End Sub

