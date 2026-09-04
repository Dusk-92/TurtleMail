-- TurtleMailFix147.lua
-- Targeted test fixes for the upcoming TurtleMail 1.4.7.
-- Loaded after TurtleMailFix.lua so the stable 1.4.6 compatibility layer remains untouched.

if not TurtleMail then return end

local m = TurtleMail
local getn = table.getn
local AUTOCOMPLETE_MAX_AGE = 60 * 60 * 24 * 30
local EPOCH_THRESHOLD = 1000000000

local function autocomplete_key()
  local realm = m.api.GetCVar and m.api.GetCVar( "realmName" ) or "UnknownRealm"
  local faction = m.api.UnitFactionGroup and m.api.UnitFactionGroup( "player" ) or "UnknownFaction"
  return tostring( realm or "UnknownRealm" ) .. "|" .. tostring( faction or "UnknownFaction" )
end

local function ensure_autocomplete_table()
  if type( m.api.TurtleMail_AutoCompleteNames ) ~= "table" then
    m.api.TurtleMail_AutoCompleteNames = {}
  end

  local key = autocomplete_key()
  if type( m.api.TurtleMail_AutoCompleteNames[ key ] ) ~= "table" then
    m.api.TurtleMail_AutoCompleteNames[ key ] = {}
  end

  return m.api.TurtleMail_AutoCompleteNames[ key ]
end

-- Older TurtleMail builds stored GetTime() values here. GetTime() is session uptime,
-- so those values cannot be compared reliably across game/client restarts. Convert
-- legacy uptime-style values to a safe current timestamp, then expire names using time().
local function migrate_and_prune_autocomplete()
  local names = ensure_autocomplete_table()
  local now = time()

  for name, last_seen in pairs( names ) do
    if type( name ) ~= "string" or type( last_seen ) ~= "number" then
      names[ name ] = nil
    else
      if last_seen < EPOCH_THRESHOLD then
        last_seen = now
        names[ name ] = last_seen
      end

      if now - last_seen > AUTOCOMPLETE_MAX_AGE then
        names[ name ] = nil
      end
    end
  end
end

-- Store persistent timestamps for newly learned recipients.
function m.add_auto_complete_name( name )
  if type( name ) ~= "string" or name == "" then return end
  local names = ensure_autocomplete_table()
  names[ name ] = time()
end

-- Keep the complete existing login flow, but migrate before the legacy cleanup
-- runs and prune again afterwards using persistent timestamps.
do
  local original = m.PLAYER_LOGIN
  function m.PLAYER_LOGIN()
    migrate_and_prune_autocomplete()
    if original then original() end
    migrate_and_prune_autocomplete()
  end
end

-- The 1.4.6 send flow can remain stuck in sendmail_sending when an attachment
-- disappears or cannot be attached between queueing and the actual SendMail call.
-- Keep the upstream behavior, but explicitly abort the send state on that failure.
function m.sendmail_send()
  if type( m.sendmail_state ) ~= "table" or type( m.sendmail_state.attachments ) ~= "table" then
    m.sendmail_sending = false
    m.sendmail_update = nil
    return
  end

  local item = table.remove( m.sendmail_state.attachments, 1 )
  if item then
    m.api.ClearCursor()
    m.orig.ClickSendMailItemButton()
    m.api.ClearCursor()
    m.orig.PickupContainerItem( unpack( item ) )
    m.orig.ClickSendMailItemButton()

    if not m.api.GetSendMailItem() then
      m.api.DEFAULT_CHAT_FRAME:AddMessage( "|cffabd473TurtleMail|r: " .. m.api.ERROR_CAPS, 1, 0, 0 )
      m.sendmail_sending = false
      m.sendmail_update = nil
      m.sendmail_state = nil
      m.api.ClearCursor()
      if m.api.SendMailFrame_Update then
        m.api.SendMailFrame_Update()
      end
      return
    end
  end

  local amount = m.sendmail_state.money
  m.sendmail_state.sent_money = m.sendmail_state.money
  m.sendmail_state.sent = false

  if amount > 0 then
    if not m.api.SendMailCODAllButton:GetChecked() then
      m.sendmail_state.money = 0
    end
    if m.sendmail_state.cod then
      m.sendmail_state.cod = amount
      m.api.SetSendMailCOD( amount )
    else
      m.sendmail_state.money = 0
      m.api.SetSendMailMoney( amount )
    end
  end

  local subject = m.sendmail_state.subject
  if subject == "" then
    if item then
      local item_name, texture, stack_count = m.api.GetSendMailItem()
      subject = item_name .. (stack_count > 1 and " (" .. stack_count .. ")" or "")
      m.sendmail_state.item = item_name
      m.sendmail_state.icon = texture
    else
      subject = "<" .. m.api.NO_ATTACHMENTS .. ">"
    end
  elseif m.sendmail_state.numMessages > 1 then
    subject = subject .. string.format( " [%d/%d]", m.sendmail_state.numMessages - getn( m.sendmail_state.attachments ),
      m.sendmail_state.numMessages )
  end

  m.sendmail_state.sent_subject = subject

  m.debug( "SendMail" )
  m.api.SendMail( m.sendmail_state.to, subject, m.sendmail_state.body )

  if getn( m.sendmail_state.attachments ) == 0 then
    m.sendmail_sending = false
  end
end
