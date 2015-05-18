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

Sub ShowUpgradeDialog(message = "This feature requires paid version of Rokagram")
	ret = ShowDialog2Buttons("Upgrade Required", message, "Learn about upgrade", "Close")
	if ret = 0
		ShowUpgradeScreen(false)
	end if
End Sub

Sub ShowUpgradeScreen(elapsed)


	globals = GetGlobals()

    port = CreateObject("roMessagePort")
    screen = CreateObject("roParagraphScreen")
    screen.SetMessagePort(port)

    if globals.usa
	    screen.AddHeaderText("Upgrade Benefits")
	    screen.AddParagraph(Chr(183) + " "+ "No banner ads")
    	screen.AddParagraph(Chr(183) + " "+ "Premium streaming music (we pay royalties)")
	    screen.AddParagraph(Chr(183) + " "+ "One time purchase, no monthly fees")
	    screen.AddParagraph(Chr(183) + " "+ "All future upgrades and features are free")
	    screen.AddParagraph(Chr(183) + " "+ "We buy more coffee = we write more code!")
	    screen.AddButton(1, "Purchase upgrade")
    else
	    screen.AddHeaderText("Please Upgrade")
	    screen.AddParagraph("The full version of Rokagram is now free outside the US.")
	    screen.AddParagraph("Please upgrade for free to continue using Rokagram")
	    screen.AddButton(1, "Free upgrade")
	    LogStoreMessage("Forced free upgrade")
    end if
    
    if NOT elapsed
    	screen.AddButton(3, "Close")
    end if
    
    screen.Show()
    
    screenOpen = true
    while screenOpen
        msg = WaitForEvent(0, port)

        if type(msg) = "roParagraphScreenEvent"
            if msg.isScreenClosed()
                print "Screen closed"
                exit while                
            else if msg.isButtonPressed()
                if msg.GetIndex() = 1
                	LogStoreMessage("Upgrade button clicked")
                	HandleInChannelUpgrade()
                else if msg.GetIndex() = 2
                	LogStoreMessage("Earn updgrade clicked")
    				HandleEarnUpgrade()
    			else if msg.GetIndex() = 3
    				LogStoreMessage("Close updgrade clicked")
					screen.Close()
					screenOpen = false
                end if
            else
                print "Unknown event: "; msg.GetType(); " msg: "; msg.GetMessage()
                exit while
            endif
        endif
    end while
    print "exiting upgrade screen"
End Sub

Sub HandleEarnUpgrade()
	globals = GetGlobals()
	
	title = "Earn Upgrade"
	message = "There are two ways to earn a free upgrade:" +chr(10) + chr(10)
	message = message + "1. Send us feedback (feedback@rokagram.com)" + chr(10) + chr(10)
	message = message + "2. Post something about Rokagram on social media " + chr(10) + chr(10)
	message = message + "For either of these to work, we need the email address your Roku is registered under. We'll never share it."
	
	
	ret = ShowDialog2Buttons(title, message, "Share email", "Close")
	if ret = 0
		store = CreateObject("roChannelStore")
		msgport = CreateObject("roMessagePort")
		store.SetMessagePort(msgport)
		
		ret = store.GetPartialUserData("email")
		if ret <> invalid
			globals.email = ret.email
			RegWrite("email", globals.email, globals.constants.sections.default)
		
			emailThanks = "We'll send further instructions to " + globals.email
			LogStoreMessage(emailThanks)
			ShowDialog1Button("Thanks!", emailThanks, "Ok")
		end if
	end if
	
End Sub

Sub HandleInChannelUpgrade()
	
	globals = GetGlobals()
		
	store = CreateObject("roChannelStore")
	msgport = CreateObject("roMessagePort")
	
	store.SetMessagePort(msgport)
	store.GetUpgrade()
	
	msg = waitForEvent(100000, msgport)
	
	if msg <> invalid
	
		if msg.isRequestSucceeded()
			LogStoreMessage("GetUpgrade.RequestSucceeded")
	
			itemCode = store.DoUpgrade()
			if itemCode <> invalid
				RegWrite(globals.constants.keys.upgrade_code, itemCode, globals.constants.sections.default)
				LogStoreMessage("DoUpgrade: " + itemCode)
			else
				LogStoreMessage("DoUpgrade: invalid")
			end if
			
		else if msg.isRequestInterrupted() 
			LogStoreMessage("GetUpgrade.RequestInterrupted: " + msg.GetStatusMessage())
		else if msg.isRequestFailed()
			LogStoreMessage("GetUpgrade.isRequestFailed: " + msg.GetStatusMessage())
		end if
	end if
                
End Sub