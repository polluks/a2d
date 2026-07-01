
a2d.ConfigureRepaintTime(0.25)

test.Step(
  "Print Screen shows alert if no SSC in slot 1",
  function()
    a2d.OpenPath("/A2.DESKTOP/EXTRAS/PRINT.SCREEN", {no_validate=true})
    a2dtest.WaitForAlert({match="Device not connected"})
    a2d.DialogOK()
end)




