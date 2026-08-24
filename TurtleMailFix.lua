-- TurtleMailFix.lua
-- Compatibility/safety layer for TurtleMail 1.4.5 on Turtle WoW 1.18.x / Octo.
-- Loaded after TurtleMail.xml so it can replace fragile handlers before ADDON_LOADED/PLAYER_LOGIN.

if not TurtleMail then return end

local m = TurtleMail
local getn = table.getn
local function pack( ... ) return arg end

m.compat_version = "1.4.6-compat.1"

local DEFAULT_SENT_FILTERS = {
  Money = 1,
  COD = 1,
  Other = 1,
}

local DEFAULT_RECEIVED_FILTERS = {
  Money = 1,
  COD = 1,
  Other = 1,
  Returned = 1,
  AH = 1,
  AHSold = 1,
  AHOutbid = 1,
  AHWon = 1,
  AHCancelled = 1,
  AHExpired = 1,
}

local INBOX_AUCTIONHOUSES = {
  [ "Stormwind Auction House" ] = true,
  [ "Alliance Auction House" ] = true,
  [ "Darnassus Auction House" ] = true,
  [ "Undercity Auction House" ] = true,
  [ "Thunder Bluff  Auction House" ] = true,
  [ "Horde Auction House" ] = true,
  [ "Blackwater Auction House" ] = true,
}

local function merge_defaults( target, defaults )
  for key, value in pairs( defaults ) do
    if target[ key ] == nil then
      target[ key ] = value
    end
  end
end

local function ensure_saved_variables()
  if type( m.api.TurtleMail_Log ) ~= "table" then
    m.api.TurtleMail_Log = {}
  end

  local log = m.api.TurtleMail_Log
  if type( log.Sent ) ~= "table" then log.Sent = {} end
  if type( log.Received ) ~= "table" then log.Received = {} end
  if type( log.Settings ) ~= "table" then log.Settings = {} end

  local settings = log.Settings
  if settings.Enabled == nil then settings.Enabled = false end

  if type( settings.SentFilters ) ~= "table" then settings.SentFilters = {} end
  if type( settings.ReceivedFilters ) ~= "table" then settings.ReceivedFilters = {} end
  merge_defaults( settings.SentFilters, DEFAULT_SENT_FILTERS )
  merge_defaults( settings.ReceivedFilters, DEFAULT_RECEIVED_FILTERS )

  if type( m.api.TurtleMail_AutoCompleteNames ) ~= "table" then
    m.api.TurtleMail_AutoCompleteNames = {}
  end
end

local function autocomplete_key()
  local realm = m.api.GetCVar and m.api.GetCVar( "realmName" ) or "UnknownRealm"
  local faction = m.api.UnitFactionGroup and m.api.UnitFactionGroup( "player" ) or "UnknownFaction"
  return tostring( realm or "UnknownRealm" ) .. "|" .. tostring( faction or "UnknownFaction" )
end

local function ensure_autocomplete_table()
  ensure_saved_variables()
  local key = autocomplete_key()
  if type( m.api.TurtleMail_AutoCompleteNames[ key ] ) ~= "table" then
    m.api.TurtleMail_AutoCompleteNames[ key ] = {}
  end
  return key, m.api.TurtleMail_AutoCompleteNames[ key ]
end

local function sanitize_autocomplete_table()
  local _, names = ensure_autocomplete_table()
  for name, last_seen in pairs( names ) do
    if type( name ) ~= "string" or type( last_seen ) ~= "number" then
      names[ name ] = nil
    end
  end
end

-- Turtle WoW/Octo can return a texture from CreateTexture without exposing it
-- through the expected global name. The original addon assumes the global exists.
local function ensure_horizontal_bars()
  local frame = m.api.SendMailFrame
  if not frame or not frame.CreateTexture then return false end

  if not m.api.MailHorizontalBarLeft then
    m.api.MailHorizontalBarLeft = frame:CreateTexture( nil, "BACKGROUND" )
  end
  if not m.api.MailHorizontalBarRight then
    m.api.MailHorizontalBarRight = frame:CreateTexture( nil, "BACKGROUND" )
  end

  return m.api.MailHorizontalBarLeft and m.api.MailHorizontalBarRight
end

-- SavedVariables are not guaranteed to have a valid schema. Repair them before
-- the original handlers touch nested fields.
do
  local original = m.ADDON_LOADED
  function m.ADDON_LOADED()
    if arg1 == "TurtleMail" then
      ensure_saved_variables()
    end
    if original then original() end
    if arg1 == "TurtleMail" and m.info then
      m.info( "Compatibility fixes loaded (|cffeda55f" .. m.compat_version .. "|r)." )
    end
  end
end

do
  local original = m.PLAYER_LOGIN
  function m.PLAYER_LOGIN()
    ensure_saved_variables()
    sanitize_autocomplete_table()
    if original then original() end
  end
end

do
  local original = m.slash_command
  function m.slash_command( args )
    ensure_saved_variables()
    if original then return original( args ) end
  end
end

-- Make autocomplete resilient to missing/corrupt SavedVariables.
do
  local original = m.add_auto_complete_name
  function m.add_auto_complete_name( name )
    if type( name ) ~= "string" or name == "" then return end
    ensure_autocomplete_table()
    if original then return original( name ) end
  end
end

if GetSuggestions then
  local original = GetSuggestions
  function GetSuggestions()
    ensure_autocomplete_table()
    return original()
  end
end

-- Ensure the two horizontal bar textures exist before the original setup/update
-- routines try to address them by global name.
do
  local original = m.sendmail_load
  function m.sendmail_load()
    ensure_horizontal_bars()
    if original then return original() end
  end
end

if m.hooks and m.hooks.SendMailFrame_Update then
  local original = m.hooks.SendMailFrame_Update
  m.hook.SendMailFrame_Update = function( ... )
    ensure_horizontal_bars()
    return original( unpack( arg ) )
  end
end

-- Do not assume MailFrame exists during bag events.
function m.BAG_UPDATE()
  if m.api.MailFrame and m.api.MailFrame:IsVisible() and m.api.SendMailFrame_Update then
    m.api.SendMailFrame_Update()
  end
end

-- Safer MAIL_SHOW: package-button regions differ between UI replacements.
function m.MAIL_SHOW()
  if not m.api.MailFrame then return end

  if m.api.TurtleMail_Point then
    m.debug( "Set point" )
    m.api.MailFrame:SetPoint( m.api.TurtleMail_Point.point, m.api.TurtleMail_Point.x, m.api.TurtleMail_Point.y )
  end

  if not m.first_show then
    m.first_show = true
    local package = m.api.SendMailPackageButton

    if package then
      if m.pfui_skin_enabled and m.api.pfUI and m.api.pfUI.api and m.api.pfUI.api.StripTextures then
        m.api.pfUI.api.StripTextures( package )
      end

      local regions = { package:GetRegions() }
      if regions[ 1 ] and regions[ 1 ].Hide then regions[ 1 ]:Hide() end
      if regions[ 3 ] and regions[ 3 ].Hide then regions[ 3 ]:Hide() end

      package:Disable()
      package:SetScript( "OnReceiveDrag", nil )
      package:SetScript( "OnDragStart", nil )
    end
  end

  if m.api.MailFrameTab3 then
    if m.log_enabled then
      m.api.MailFrameTab3:Show()
    else
      m.api.MailFrameTab3:Hide()
    end
  end

  m.timer = 0
  m.money_received = 0
  m.update_money( 0 )
end

-- Check bounds before querying inbox headers and tolerate nil COD values.
function m.on_update()
  if not m.api.MailFrame or not m.api.MailFrame:IsVisible() then return end

  if m._cursorItem then
    m.debug( "on_update: cursorItem" )
    m.cursorItem = m._cursorItem
    m._cursorItem = nil
  end

  if m.sendmail_update then
    m.debug( "on_update: sendmail" )
    m.sendmail_update = nil
    if m.sendmail_sending then
      m.debug( "m.sendmail_sending" )
      m.sendmail_send()
    end
  end

  if m.inbox_update then
    m.debug( "on_update: inbox_update" )
    m.inbox_update = false

    local index = tonumber( m.inbox_index ) or 1
    local total = m.api.GetInboxNumItems and (m.api.GetInboxNumItems() or 0) or 0

    if index > total then
      if (tonumber( m.money_received ) or 0) > 0 then
        m.info( string.format( "%s%s.", m.format_money( m.money_received ), L[ "collected" ] ) )
      end
      m.inbox_abort()
    else
      local _, _, _, _, _, cod, _, _, _, _, _, _, isGM = m.api.GetInboxHeaderInfo( index )
      cod = tonumber( cod ) or 0

      if m.inbox_skip or cod > 0 or isGM then
        m.inbox_skip = false
        m.inbox_index = index + 1
        m.inbox_update = true
      else
        m.inbox_open( index )
      end
    end
  end

  if type( m.timer ) ~= "number" then m.timer = 0 end
  if m.timer > 0 then
    m.timer = m.timer - 1
  elseif not m.inbox_opening and m.api.CheckInbox then
    m.timer = 200
    m.api.CheckInbox()
  end
end

-- init() bound the original on_update function before this compatibility file was
-- loaded. Rebind the frame script so the safer implementation above is actually used.
if m.update_frame and m.update_frame.SetScript then
  m.update_frame:SetScript( "OnUpdate", m.on_update )
end

-- Hide stale AH/returned icons on rows that no longer contain mail.
function m.MAIL_INBOX_UPDATE()
  if m.inbox_opening then
    m.inbox_update = true
  end

  if not m.api.InboxFrame then return end
  local page = tonumber( m.api.InboxFrame.pageNum ) or 1
  local total = m.api.GetInboxNumItems and (m.api.GetInboxNumItems() or 0) or 0

  for i = 1, 7 do
    local index = i + (page - 1) * 7
    local auction_icon = m.api[ "TurtleMailAuctionIcon" .. i ]
    local returned_icon = m.api[ "TurtleMailReturnedArrow" .. i ]

    if index <= total then
      local _, _, sender, _, _, _, _, _, _, was_returned = m.api.GetInboxHeaderInfo( index )
      if auction_icon then
        if INBOX_AUCTIONHOUSES[ sender ] then auction_icon:Show() else auction_icon:Hide() end
      end
      if returned_icon then
        if was_returned then returned_icon:Show() else returned_icon:Hide() end
      end
    else
      if auction_icon then auction_icon:Hide() end
      if returned_icon then returned_icon:Hide() end
    end
  end
end

-- Guard frame lookups used while the mailbox is opening/closing.
function m.inbox_update_lock()
  for i = 1, 7 do
    local icon = m.api[ "MailItem" .. i .. "ButtonIcon" ]
    local button = m.api[ "MailItem" .. i .. "Button" ]

    if icon and icon.SetDesaturated then
      icon:SetDesaturated( m.inbox_opening )
    end
    if m.inbox_opening and button and button.SetChecked then
      button:SetChecked( nil )
    end
  end
end

-- Locale-safe COD label.
function m.set_cod_text()
  local cod_amount = m.api.COD_AMOUNT or "COD:"
  local text = string.sub( cod_amount, 1, math.max( 0, string.len( cod_amount ) - 1 ) )

  if not m.pfui_skin_enabled then
    text = string.match( text, "^(.-)%s+%S+$" ) or text
  end

  if not m.api.SendMailMoneyText then return end
  if m.api.SendMailCODAllButton and m.api.SendMailCODAllButton:GetChecked() then
    m.api.SendMailMoneyText:SetText( text .. " " .. L[ "each mail" ] .. ":" )
  else
    m.api.SendMailMoneyText:SetText( text .. " " .. L[ "1st mail" ] .. ":" )
  end
end

function m.update_money( money )
  m.money_received = (tonumber( m.money_received ) or 0) + (tonumber( money ) or 0)
  if not m.api.MoneyReceived then return end

  m.api.MoneyReceived:SetText( L[ "Money received" ] .. ": " .. m.format_money( m.money_received ) )
  if m.money_received > 0 then
    m.api.MoneyReceived:Show()
  else
    m.api.MoneyReceived:Hide()
  end
end

-- The original hook reads arg[3]/arg[12] from the function INPUT arguments.
-- GetInboxHeaderInfo receives an inbox index; sender/canReply are RETURN values.
-- Capture the return list first so sender autocomplete actually works.
if m.hooks and m.hooks.GetInboxHeaderInfo then
  m.hook.GetInboxHeaderInfo = function( ... )
    if not m.orig.GetInboxHeaderInfo then return end
    local ret = pack( m.orig.GetInboxHeaderInfo( unpack( arg ) ) )
    local sender = ret[ 3 ]
    local canReply = ret[ 12 ]
    if sender and canReply then
      m.add_auto_complete_name( sender )
    end
    return unpack( ret )
  end
end

-- Guard MailFrame lookup in attachment bookkeeping.
do
  local original = m.sendmail_attached
  function m.sendmail_attached( bag, slot )
    if not m.api.MailFrame or not m.api.MailFrame:IsVisible() then return false end
    if original then return original( bag, slot ) end
    return false
  end
end

-- Fix sent-money logging and tolerate malformed/system mail subjects.
function m.log.add( log_type, state )
  if not m.log_enabled or type( state ) ~= "table" then return end
  ensure_saved_variables()
  m.debug( "Logging " .. tostring( log_type ) .. " message" )

  local data = {
    timestamp = time(),
    icon = state.icon,
    item = state.item,
  }

  local cod = tonumber( state.cod )
  if cod and cod > 0 then data.cod = cod end

  if log_type == "Sent" then
    data.participant = state.to or ""
    data.subject = state.sent_subject or state.subject or ""

    local sent_money = tonumber( state.sent_money ) or 0
    if not data.cod and sent_money > 0 then
      data.money = sent_money
    end
  else
    data.participant = state.from or ""
    data.subject = state.subject or ""
    data.returned = state.returned
    data.gm = state.gm

    local received_money = tonumber( state.money ) or 0
    if received_money > 0 then data.money = received_money end

    local function subject_matches( pattern )
      if type( pattern ) ~= "string" or pattern == "" or data.subject == "" then return false end
      local needle = string.gsub( pattern, "%%s", "" )
      return needle ~= "" and string.find( data.subject, needle, 1, true ) ~= nil
    end

    if subject_matches( m.api.AUCTION_SOLD_MAIL_SUBJECT ) then
      data.ah = "Sold"
    elseif subject_matches( m.api.AUCTION_REMOVED_MAIL_SUBJECT ) then
      data.ah = "Removed"
    elseif subject_matches( m.api.AUCTION_EXPIRED_MAIL_SUBJECT ) then
      data.ah = "Expired"
    elseif subject_matches( m.api.AUCTION_WON_MAIL_SUBJECT ) then
      data.ah = "Won"
    elseif subject_matches( m.api.AUCTION_OUTBID_MAIL_SUBJECT ) then
      data.ah = "Outbid"
    end
  end

  if type( m.api.TurtleMail_Log[ log_type ] ) ~= "table" then
    m.api.TurtleMail_Log[ log_type ] = {}
  end
  table.insert( m.api.TurtleMail_Log[ log_type ], data )
end

-- Calendar day buttons can retain an old .mails value or have no value at all.
-- Replace only the tooltip handler; calendar selection/layout remains upstream.
if m.calendar and m.calendar.show then
  local original_show = m.calendar.show

  local function calendar_on_enter( button )
    return function()
      local enabled = true
      if button.IsEnabled then enabled = button:IsEnabled() end
      local mails = tonumber( button.mails ) or 0

      if enabled and mails > 0 then
        m.api.GameTooltip:SetOwner( button, "ANCHOR_RIGHT" )
        m.api.GameTooltip:SetText( mails .. " mail" .. (mails > 1 and "s" or ""), 1, 1, 1, 1, true )
        m.api.GameTooltip:Show()
      else
        m.api.GameTooltip:Hide()
      end
    end
  end

  m.calendar.show = function( data, current_date, anchor, on_select )
    if type( data ) ~= "table" then data = {} end
    original_show( data, current_date or time(), anchor, on_select )

    for i = 1, 42 do
      local button = m.api[ "TurtleMailCalendarDay" .. i .. "Button" ]
      if button then
        button:SetScript( "OnEnter", calendar_on_enter( button ) )
      end
    end
  end
end
