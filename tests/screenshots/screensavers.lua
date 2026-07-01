--[[============================================================

  Dump all the Screen Savers

  ============================================================]]

a2d.ConfigureRepaintTime(1)

test.Step(
  "Analog Clock",
  function()
    a2d.OpenPath(a2d.GetLocalizedPath("/A2.DESKTOP/APPLE.MENU/SCREEN.SAVERS/ANALOG.CLOCK"), {no_validate=true})
    emu.wait(0.5)
    test.Snap("Analog Clock")
    apple2.EscapeKey()
    a2d.WaitForRepaint()
end)

test.Step(
  "Digital Clock",
  function()
    a2d.OpenPath(a2d.GetLocalizedPath("/A2.DESKTOP/APPLE.MENU/SCREEN.SAVERS/DIGITAL.CLOCK"), {no_validate=true})
    emu.wait(0.5)
    test.Snap("Digital Clock")
    apple2.EscapeKey()
    a2d.WaitForRepaint()
end)

test.Step(
  "Flying Toasters",
  function()
    a2d.OpenPath(a2d.GetLocalizedPath("/A2.DESKTOP/APPLE.MENU/SCREEN.SAVERS/FLYING.TOASTERS"), {no_validate=true})
    emu.wait(2)
    test.Snap("Flying Toasters")
    apple2.EscapeKey()
    a2d.WaitForRepaint()
end)

test.Step(
  "Helix",
  function()
    a2d.OpenPath(a2d.GetLocalizedPath("/A2.DESKTOP/APPLE.MENU/SCREEN.SAVERS/HELIX"), {no_validate=true})
    emu.wait(0.5)
    test.Snap("Helix")
    apple2.EscapeKey()
    a2d.WaitForRepaint()
end)

test.Step(
  "Invert",
  function()
    a2d.OpenPath(a2d.GetLocalizedPath("/A2.DESKTOP/APPLE.MENU/SCREEN.SAVERS/INVERT"), {no_validate=true})
    emu.wait(0.5)
    test.Snap("Invert")
    apple2.EscapeKey()
    a2d.WaitForRepaint()
end)

test.Step(
  "Matrix",
  function()
    a2d.OpenPath(a2d.GetLocalizedPath("/A2.DESKTOP/APPLE.MENU/SCREEN.SAVERS/MATRIX"), {no_validate=true})
    emu.wait(1)
    test.Snap("Matrix")
    apple2.EscapeKey()
    a2d.WaitForRepaint()
end)

test.Step(
  "Maze",
  function()
    a2d.OpenPath(a2d.GetLocalizedPath("/A2.DESKTOP/APPLE.MENU/SCREEN.SAVERS/MAZE"), {no_validate=true})
    emu.wait(5)
    test.Snap("Maze")
    apple2.EscapeKey()
    a2d.WaitForRepaint()
end)

test.Step(
  "Melt",
  function()
    a2d.OpenPath(a2d.GetLocalizedPath("/A2.DESKTOP/APPLE.MENU/SCREEN.SAVERS/MELT"), {no_validate=true})
    emu.wait(1)
    test.Snap("Melt")
    apple2.EscapeKey()
    a2d.WaitForRepaint()
end)

test.Step(
  "Message",
  function()
    a2d.OpenPath(a2d.GetLocalizedPath("/A2.DESKTOP/APPLE.MENU/SCREEN.SAVERS/MESSAGE"), {no_validate=true})
    emu.wait(0.5)
    test.Snap("Message")
    apple2.EscapeKey()
    a2d.WaitForRepaint()
end)

test.Step(
  "Rod's Pattern",
  function()
    a2d.OpenPath(a2d.GetLocalizedPath("/A2.DESKTOP/APPLE.MENU/SCREEN.SAVERS/RODS.PATTERN"), {no_validate=true})
    emu.wait(5)
    test.Snap("Rod's Pattern")
    apple2.EscapeKey()
    a2d.WaitForRepaint()
end)
