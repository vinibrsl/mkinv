local text = pandoc.utils.stringify

local months = {
  "January", "February", "March", "April", "May", "June",
  "July", "August", "September", "October", "November", "December"
}

local function format_date(date)
  local year, month, day = text(date):match("^(%d%d%d%d)%-(%d%d)%-(%d%d)$")
  return pandoc.MetaString(string.format("%s %d, %s", months[tonumber(month)], tonumber(day), year))
end

local function to_cents(amount)
  return math.floor(amount * 100 + 0.5)
end

local function format_money(cents, currency)
  local whole, fraction = string.format("%.2f", cents / 100):match("^(%d+)%.(%d+)$")
  local grouped = whole:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
  local symbol = currency == "USD" and "$" or ""
  return pandoc.MetaInlines({ pandoc.Str(symbol .. grouped .. "." .. fraction) })
end

local function format_item(item, currency)
  local quantity = tonumber(text(item.quantity):match("^%s*(%S+)"))
  local rate = tonumber(text(item.rate))
  assert(quantity and quantity >= 0, "Each quantity must start with a nonnegative number")
  assert(rate and rate >= 0, "Each item needs a nonnegative rate")

  local amount = to_cents(quantity * rate)
  item.amount = format_money(amount, currency)
  item.rate = format_money(to_cents(rate), currency)
  return amount
end

function Link(link)
  if link.target:match("^https?://") then
    link.content = { pandoc.Underline(link.content) }
    return link
  end
end

function Meta(invoice)
  invoice.date = format_date(invoice.date)
  local currency = text(invoice.currency)
  local total = 0
  local note_number = 0

  for _, item in ipairs(invoice.items) do
    if item.note then
      note_number = note_number + 1
      item.note_number = pandoc.MetaString(tostring(note_number))
    end
    total = total + format_item(item, currency)
  end

  invoice.total = format_money(total, currency)
  return invoice
end
