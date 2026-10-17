' Runtime for generated scripts. No global error suppression.
' Every generated COM call captures Err immediately, restores normal handling,
' and stops before any subsequent mutation on failure.
Sub State(code, message)
    Dim file
    Set file = fs.OpenTextFile(statusPath, 8, True, -1)
    file.WriteLine "STATE|" & code & "|" & CStr(Now) & "|" & message
    file.Close
End Sub

Sub Note(message)
    Dim file
    Set file = fs.OpenTextFile(statusPath, 8, True, -1)
    file.WriteLine "NOTE|" & CStr(Now) & "|" & message
    file.Close
End Sub

Sub Fail(stage, number, message)
    Dim recoveryError
    State "FAILED", stage & "|" & CStr(number) & "|" & message
    ' Recovery is confined to this job's unique path, never the input file.
    If IsObject(oProject) Then
        On Error Resume Next
        oProject.SaveAs recoveryPath, True
        recoveryError = Err.Number
        Err.Clear
        On Error GoTo 0
        Note "Recovery save error code: " & CStr(recoveryError)
    End If
    Err.Raise 513, "VivaldiBuilder: " & stage, message
End Sub

Function CountItems(items)
    Dim item, count
    count = 0
    If IsArray(items) Then
        For Each item In items
            count = count + 1
        Next
    End If
    CountItems = count
End Function

Function AllObjects()
    Dim group, item, result, members
    result = ""
    For Each group In Array("Solids", "Sheets", "Lines", "Unclassified")
        members = oEditor.GetObjectsInGroup(group)
        If IsArray(members) Then
            For Each item In members
                If result <> "" Then result = result & "|"
                result = result & CStr(item)
            Next
        End If
    Next
    AllObjects = result
End Function

Function NewObjectNames(before)
    Dim item, result
    result = ""
    For Each item In Split(AllObjects(), "|")
        If InStr(1, "|" & before & "|", "|" & item & "|", vbBinaryCompare) = 0 Then
            If result <> "" Then result = result & ","
            result = result & item
        End If
    Next
    NewObjectNames = result
End Function

Function SingleNewObject(before)
    Dim item, count, found
    count = 0
    For Each item In Split(AllObjects(), "|")
        If InStr(1, "|" & before & "|", "|" & item & "|", vbBinaryCompare) = 0 Then
            count = count + 1
            found = item
        End If
    Next
    If count <> 1 Then Fail "Clone mapping", 513, "Expected exactly one new object; got " & count
    SingleNewObject = found
End Function

Sub Inventory()
    Dim expected, actual, item, value, excitations, boundaries
    expected = "Vivaldi_1|cable_in|cable_out|cable_in_1|cable_out_1|port1|port2|RadiatingSurface"
    actual = AllObjects()
    If UBound(Split(actual, "|")) <> 7 Then Fail "Inventory", 513, "Expected eight top-level objects: " & actual
    For Each item In Split(expected, "|")
        If InStr(1, "|" & actual & "|", "|" & item & "|", vbBinaryCompare) = 0 Then
            Fail "Inventory", 513, "Missing object " & item
        End If
    Next
    If CountItems(oEditor.GetObjectsInGroup("Solids")) <> 6 Then Fail "Inventory", 513, "Expected six solids"
    If CountItems(oEditor.GetObjectsInGroup("Sheets")) <> 2 Then Fail "Inventory", 513, "Expected two port sheets"
    For Each item In Array("Vivaldi_1", "cable_in", "cable_out", "cable_in_1", "cable_out_1")
        value = oEditor.GetPropertyValue("Geometry3DAttributeTab", item, "Material")
        If item = "Vivaldi_1" Then
            If InStr(1, value, "aluminum", vbTextCompare) = 0 Then Fail "Inventory", 513, "Antenna material mismatch"
        Else
            If InStr(1, value, "copper", vbTextCompare) = 0 Then Fail "Inventory", 513, "Coax material mismatch"
        End If
        If CDbl(oEditor.GetObjectVolume(item)) <= 0 Then Fail "Inventory", 513, "Zero volume " & item
    Next
    excitations = oBoundary.GetExcitations()
    If CountItems(excitations) <> 4 Then Fail "Inventory", 513, "Expected two excitations"
    For Each item In Array("1", "2")
        If Not PairExists(excitations, item, "Lumped Port") Then Fail "Inventory", 513, "Missing lumped port " & item
    Next
    boundaries = oBoundary.GetBoundaries()
    If Not PairExists(boundaries, "Open1", "Radiation") Then Fail "Inventory", 513, "Missing Radiation Open1"
    If oDesign.GetSolutionType() <> "DrivenModal" Then Fail "Inventory", 513, "Not DrivenModal"
    Note "INVENTORY|" & actual
    Note "PORTS|" & Join(excitations, "|")
    Note "BOUNDARIES|" & Join(boundaries, "|")
End Sub

Function PairExists(items, name, kind)
    Dim i
    PairExists = False
    If Not IsArray(items) Then Exit Function
    For i = 0 To UBound(items)-1 Step 2
        If CStr(items(i)) = name And CStr(items(i+1)) = kind Then PairExists = True
    Next
End Function

Function FindPortLine(sheet, conductor, cx, cy, cz, outerRadius, innerRadius)
    Dim edges, edge, p, q, dot, cross, outerPoint, innerPoint, found, radius, tol
    tol = 0.00001
    found = False
    edges = oEditor.GetEdgeIDsFromObject(sheet)
    For Each edge In edges
        p = oEditor.GetEdgePositionAtNormalizedParameter(edge, 0.5)
        radius = Sqr((CDbl(p(0))-cx)^2 + (CDbl(p(1))-cy)^2)
        If Abs(CDbl(p(2))-cz) < tol And Abs(radius-outerRadius) < tol Then
            outerPoint = p
            found = True
            Exit For
        End If
    Next
    If Not found Then Fail "Port integration line", 513, "Cannot find actual outer circular edge for " & sheet
    found = False
    For Each edge In oEditor.GetEdgeIDsFromObject(conductor)
        q = oEditor.GetEdgePositionAtNormalizedParameter(edge, 0.5)
        radius = Sqr((CDbl(q(0))-cx)^2 + (CDbl(q(1))-cy)^2)
        If Abs(CDbl(q(2))-cz) < tol And Abs(radius-innerRadius) < tol Then
            dot = (CDbl(outerPoint(0))-cx)*(CDbl(q(0))-cx) + (CDbl(outerPoint(1))-cy)*(CDbl(q(1))-cy)
            cross = (CDbl(outerPoint(0))-cx)*(CDbl(q(1))-cy) - (CDbl(outerPoint(1))-cy)*(CDbl(q(0))-cx)
            If dot > 0 And Abs(cross) < tol*outerRadius Then
                innerPoint = q
                found = True
                Exit For
            End If
        End If
    Next
    If Not found Then Fail "Port integration line", 513, "No aligned inner-conductor edge at the port plane; inspect seam orientation"
    Note "PORT_LINE|" & sheet & "|OUTER_TO_INNER|" & Join(outerPoint, "|") & "|" & Join(innerPoint, "|")
    FindPortLine = Array(PointWithUnits(outerPoint), PointWithUnits(innerPoint))
End Function

Function PointWithUnits(point)
    ' API point strings use a decimal point regardless of the Windows locale.
    PointWithUnits = Array(Replace(CStr(point(0)), ",", ".") & "mm", _
        Replace(CStr(point(1)), ",", ".") & "mm", Replace(CStr(point(2)), ",", ".") & "mm")
End Function

Sub ValidateModel()
    Dim result
    result = oDesign.ValidateDesign(validationPath)
    Note "VALIDATE_RETURN|" & CStr(result)
    If Not IsNumeric(result) Then Fail "Validate", 513, "Unrecognized ValidateDesign result"
    ' Ansys Hfss.validate_full_design interprets 1 as passed and 0 as error.
    If CLng(result) <> 1 Then Fail "Validate", 513, "HFSS validation failed; see validation log"
End Sub

Sub RequireSolution(solution, expectedPoints)
    Dim data, values, frequencies, solutionData
    data = oReport.GetSolutionDataPerVariation("Modal Solution Data", solution, Array(), _
        Array("Freq:=", Array("All")), Array("dB(S(1,1))"))
    If CountItems(data) = 0 Then Fail "Solve", 513, "Analyze returned without solution data"
    Set solutionData = data(0)
    values = solutionData.GetRealDataValues("dB(S(1,1))")
    frequencies = solutionData.GetSweepValues("Freq")
    If CountItems(values) = 0 Or CountItems(values) <> CountItems(frequencies) Then
        Fail "Solve", 513, "Empty or inconsistent S-parameter solution data"
    End If
    If CountItems(values) < expectedPoints Then Fail "Solve", 513, "Incomplete frequency sweep"
    values = solutionData.GetRealDataValues("dB(S(2,2))")
    If CountItems(values) <> CountItems(frequencies) Then Fail "Solve", 513, "Missing S22 solution samples"
    Note "SOLUTION_POINTS|" & CountItems(values)
End Sub
