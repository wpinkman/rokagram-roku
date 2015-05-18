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

Function CreateAboutScreen() As Object
	this = {
	
		screen: CreateObject("roParagraphScreen"),
		port: CreateObject("roMessagePort"),
		
		AddButtons: AboutScreenAddButtons,
		
		Initialize: AboutScreenInitialize,
		
		ProcessEvents: AboutScreenProcessEvents,
		Show: AboutScreenShow,
		
		Run: function() : m.Show() : m.ProcessEvents() : return invalid : end function,
		
		Close: function() :  m.screen.Close() :  return m.screen : end function
		
	}

	this.screen.SetMessagePort(this.port)
	
	this.Initialize()
			
	return this
	
End Function

Sub AboutScreenShow()
	m.screen.Show()
	GaScreenView("about").PostAsync()
End Sub

Sub AboutScreenAddButtons()
	globals = GetGlobals()
	
	if globals.trial
		m.btnUpgrade = 0
		m.screen.AddButton(m.btnUpgrade, "Learn about upgrade")
	end if
	
	m.btnContributors = 1
	m.screen.AddButton(m.btnContributors, "Contributors")
	m.btnBack = 3
	m.screen.AddButton(m.btnBack, "Back")
	
End Sub	

Sub AboutScreenInitialize()
	
	globals = GetGlobals()

	m.screen.AddHeaderText("Version")
	v = globals.cversion
	if globals.trial
		if globals.expired
			v = v + " (Free Version)"
		else
			v = v + " (Trial Version)"
		end if
	end if
		
	m.screen.AddParagraph(v)
	
	m.screen.AddHeaderText("Contact")
	m.screen.AddParagraph("Instagram: @getrokagram")
	m.screen.AddParagraph("Twitter: @getrokagram")
	m.screen.AddParagraph("Email: feedback@rokagram.com")
	
	m.AddButtons()
	
	LogAboutMessage("loaded")
	
End Sub


Function AboutScreenProcessEvents()
	
	globals = GetGlobals()

	while true 
		
		msg = WaitForEvent(0, m.port)
		
		if type(msg) = "roParagraphScreenEvent"
		
			if msg.isScreenClosed() then 
				return -1
			else if msg.isButtonPressed() 
				index = msg.GetIndex()
				
				if index = m.btnBack then
					m.screen.Close()
					return 0
				else if index = m.btnUpgrade
					ShowUpgradeScreen(false)
				else if index = m.btnContributors
					screen = CreateUsersPoster()
					contributorUser = {}
					contributorUser.id = "1376912104"
					contributorUser.access_token = "1376912104.c54578d.4aae878dfc3e4089a055a69456d3a28e"
					screen.contrib_mode = true
					LogAboutMessage("Running contributors")
					screen.RunRelations(contributorUser, "follows")

				end if
			end if
		end if
	end while
End Function

Sub AboutScreenHandleRelationShipResponse(msg)
	json = msg.GetString()
	response = ParseJson(json)
	' {"meta":{"code":200},"data":{"outgoing_status":"follows","target_user_is_private":false}}
	if response.meta.code = 200 then
		if response.data.outgoing_status <> m.outgoing_status then
			m.Initialize()
		end if
		
	end if
				
End Sub