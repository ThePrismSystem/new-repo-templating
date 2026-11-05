local names = require("names")

describe("display_name", function()
  it("joins the parts with single spaces", function()
    assert.are.equal("Ada Lovelace", names.display_name("Ada", "Lovelace"))
  end)

  it("trims each part and leaves out blank ones", function()
    assert.are.equal("Ada Lovelace", names.display_name("  Ada ", "", "   ", "Lovelace"))
  end)

  it("returns an empty string for no parts", function()
    assert.are.equal("", names.display_name())
  end)
end)
