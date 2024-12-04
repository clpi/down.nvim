local I = Mod.create("lsp.declaration")

function I.setup()
  return {
    requires = {
      "workspace",
    },
    loaded = true,
  }
end

I.config.public = {
  enable = true
}

I.data = {}

return I
