# HFSS 2021 R2 Automation API compatibility evidence

This is API research for the MATLAB single-element builder, not a claim that the generated CAD or solver has run. The cloud machine has neither Windows COM nor HFSS. The reference is `17_10_2026_vivaldi.aedt`, design `dual_pol_vivaldi_patch_Wflare_20`. The source AEDT file is the geometry authority; operation IDs below are evidence only and must never be reused as rebuilt entity IDs.

## Evidence and version limits

Sources were retrieved over HTTPS with normal TLS verification. Ansys-hosted help pages and GitHub API endpoints were blocked by the environment's proxy (403), so the accessible official Ansys PyAEDT repository was used as additional API evidence. PyAEDT is a research reference only; users do not need to install it.

* [Official PyAEDT v0.4.0 README](https://raw.githubusercontent.com/ansys/pyaedt/v0.4.0/README.rst), lines 51–59, explicitly states support through **2021 R2**.
* [v0.4.0 desktop.py](https://raw.githubusercontent.com/ansys/pyaedt/v0.4.0/pyaedt/desktop.py), `_set_version`, constructs the version-specific Automation ProgID.
* [v0.4.0 Modeler.py](https://raw.githubusercontent.com/ansys/pyaedt/v0.4.0/pyaedt/modeler/Modeler.py): coordinate systems, duplicate, copy/paste, thicken, booleans.
* [v0.4.0 Primitives3D.py](https://raw.githubusercontent.com/ansys/pyaedt/v0.4.0/pyaedt/modeler/Primitives3D.py): rectangle and circle parameter blocks.
* [v0.4.0 Primitives.py](https://raw.githubusercontent.com/ansys/pyaedt/v0.4.0/pyaedt/modeler/Primitives.py): object inventory, region and property changes.
* [v0.4.0 Object3d.py](https://raw.githubusercontent.com/ansys/pyaedt/v0.4.0/pyaedt/modeler/Object3d.py): rename property shape.
* [v0.4.0 Analysis3D.py](https://raw.githubusercontent.com/ansys/pyaedt/v0.4.0/pyaedt/application/Analysis3D.py): `AssignMaterial`.
* [v0.4.0 hfss.py](https://raw.githubusercontent.com/ansys/pyaedt/v0.4.0/pyaedt/hfss.py): coordinate-based lumped ports and source powers.
* [v0.4.0 Design.py](https://raw.githubusercontent.com/ansys/pyaedt/v0.4.0/pyaedt/application/Design.py): validation return status and parameter evaluation.
* [v0.4.0 PostProcessor.py](https://raw.githubusercontent.com/ansys/pyaedt/v0.4.0/pyaedt/modules/PostProcessor.py): report creation, data query and CSV export.
* [v0.5.0 Boundary.py](https://raw.githubusercontent.com/ansys/pyaedt/v0.5.0/pyaedt/modules/Boundary.py): `InsertInfiniteSphereSetup`; the v0.4.0 wrapper has no far-field creation helper.
* [Current official Primitives3D source](https://raw.githubusercontent.com/ansys/pyaedt/main/src/ansys/aedt/core/modeler/cad/primitives_3d.py): `CreateEquationSurface` and equation block. The v0.4.0 wrapper has no equation-surface helper; this method spelling still needs a real 2021 R2 runtime check.

The old library has some literal typos, notably `Materiaobjidue` in its region attributes and `Name:RelativeCSParameters` in a coordinate-system helper. Those are not authoritative parameter names to propagate. Correct parameter names are cross-checked against the model and newer official code.

## Connection, coordinate systems, and variables

For 2021 R2 use `Ansoft.ElectronicsDesktop.2021.2`, obtain `GetAppDesktop()`, and check `oDesktop.GetVersion()`. A generic ProgID can start a different installed release and is insufficient evidence of a 2021 R2 connection.

`oEditor.SetWCS Array("NAME:SetWCS Parameter", "Working Coordinate System:=", name, "RegionDepCSOk:=", False)` selects the operation reference frame. `CreateRelativeCS` takes a `NAME:RelativeCSParameters` block with `Mode:="Axis/Position"`, expression-valued `OriginX/Y/Z`, `XAxisXvec/Yvec/Zvec`, `YAxisXvec/Yvec/Zvec`, followed by a `NAME:Attributes` block with `Name:=`.

A parent CS can be assigned explicitly with:

```vb
Array("NAME:AllTabs", Array("NAME:Geometry3DCSTab", _
  Array("NAME:PropServers", csName), _
  Array("NAME:ChangedProps", Array("NAME:Reference CS", "Value:=", parentName))))
```

The v0.4.0 coordinate helper makes this property update after creation. Reference `RelativeCS1` has parent `patch_td`; its local origin is `(0,-thickness/2,0)`. Treating those local values as Global moves the rotation pivot.

`oDesign.GetVariationVariableValue(oDesign.GetNominalVariation(), variableName)` evaluates the variable and returns numeric **SI units**, as documented by v0.4.0 `get_evaluated_value`. Convert metres to millimetres before comparing with MATLAB reference values.

## Geometry calls

### Equation surface

The Automation method is **`oEditor.CreateEquationSurface`**, not `CreateEquationBasedSurface`. Its parameter block is named `EquationBasedSurfaceParameters`:

```vb
Array("NAME:EquationBasedSurfaceParameters", _
 "XuvFunction:=", "_v*((slot_feed_w/2)*exp((_u)*r_flare))", _
 "YuvFunction:=", "0", "ZuvFunction:=", "_u", _
 "uStart:=", "0", "uEnd:=", "L_flare", _
 "vStart:=", "-1", "vEnd:=", "1", "Version:=", 1)
```

Pass normal object attributes as its second argument. The function variables are `_u` and `_v`; these exact expressions and range tokens appear in the original operation 5903. Only the shorter surface uses `uEnd:="slot_t_L"`.

### Rectangles, circles, and covering

`CreateRectangle` takes `NAME:RectangleParameters`, `IsCovered:=`, `XStart/YStart/ZStart:=`, `Width:=`, `Height:=`, `WhichAxis:=`. For `WhichAxis="Y"`, the source shows width along **local Z**, height along **local X**. The reference patch starts at `(10,0,46.4)` with width `-L_patch`, height `-aperture_w`; its resulting bounds are X=-10..10 and Z=-2.836303290..46.4 mm. Do not transpose the two dimensions.

The source rectangle history has `NumFaces=0` followed by `CoverLines`, so its faithful reproduction is `IsCovered=False` then:

```vb
oEditor.CoverLines Array("NAME:Selections", "Selections:=", name, "NewPartsModelFlag:=", "Model")
```

The same wire-then-cover history exists for each circular port. `CreateCircle` uses `NAME:CircleParameters`, `IsCovered`, `XCenter/YCenter/ZCenter`, `Radius`, `WhichAxis`, and `NumSegments:="0"`.

### Thickening

Automation uses **`oEditor.ThickenSheet`**, with a `NAME:SheetThickenParameters` block containing `Thickness:="thickness"`, `BothSides:=True`. The UI/history operation is named `SheetThicken`, so confusing that history name with the API method is unsafe.

**With BothSides=True the specified value is total thickness.** The original AEDT operation 5758 uses `thickness=2mm` and creates face 5759 at Y=-1 mm and face 5760 at Y=+1 mm. Do not divide the requested thickness by two.

### Copying, duplication, rename, and material

`Copy Array("NAME:Selections","Selections:=",name)` followed by `Paste()` is supported. Compare object inventories before and after to find copied names.

`DuplicateAroundAxis` takes three blocks:

```vb
Array("NAME:Selections","Selections:=",name,"NewPartsModelFlag:=","Model")
Array("NAME:DuplicateAroundAxisParameters","CreateNewObjects:=",True, _
 "WhichAxis:=","Z","AngleStr:=","-90deg","Numclones:=","2")
Array("NAME:Options","DuplicateBoundaries:=","true")
```

The 2021-era wrapper uses `DuplicateBoundaries`; newer code uses `DuplicateAssignments`. The original remains and one new object is created for Numclones=2. The API returns the names in v0.4.0, but the bridge should verify the observed inventory instead of guessing `_1` names. Duplicate before assigning ports to avoid unintended copied excitation assignments.

`Move` takes selection and `NAME:TranslateParameters` (`TranslateVectorX/Y/Z:=`). The active WCS governs the vector. Restore Global explicitly before a Global `(0,thickness,0)` move.

Rename uses `ChangeProperty` with `AllTabs` → `Geometry3DAttributeTab` → `PropServers(oldName)` → `ChangedProps` → `NAME:Name`, `Value:=newName`.

`AssignMaterial` takes `NAME:Selections`/`Selections:=` and `NAME:Attributes`/`MaterialValue:="""aluminum"""`/`SolveInside:=False`. Copper conductors also solve outside. Vacuum region and port sheets use SolveInside=True. Do not leave SolveInside=True inherited from an intermediate sheet on the finished metal.

`GetObjectsInGroup("Solids")`, `("Sheets")`, `("Lines")`, and `("Unclassified")` all appear in official v0.4.0 inventory methods. The old Unclassified helper catches COM errors; an unavailable query must be reported as unknown, not interpreted as an empty group.

### Open region

`CreateRegion` takes `NAME:RegionParameters`, with `+XPaddingType:=`, `-XPaddingType:=`, etc. set to `Absolute Offset` and all six padding values `20mm`. Order is not significant for key/value pairs. Object attributes use `Flags:="Wireframe#"`, `PartCoordinateSystem:="Global"`, `MaterialValue:="""vacuum"""`, `SolveInside:=True`. `Wireframe#` is a display flag, not `NonModel`. A non-model region cannot serve as the solution volume.

Create the region only after the physical antenna exists; do not Unite it with conductors. `BoundarySetup.AssignRadiation` assigns `Open1` to `Objects:=Array(regionName)`, with `IsIncidentField:=False`, `IsEnforcedField:=False`, `IsFssReference:=False`, `IsForPML:=False` if these optional settings are used.

## Ports, sources, setup and validation

`BoundarySetup.AssignLumpedPort` supports object-name assignment and explicit coordinate-based integration lines. The 2021-era wrapper builds `Objects:=Array(portName)`, `DoDeembed:=False`, `RenormalizeAllTerminals:=True`, a nested `Modes/Mode1` block containing `ModeNum:=1`, `UseIntLine:=True`, `IntLine/Start:=Array(x,y,z)`, `End:=Array(x,y,z)`, `AlignmentGroup:=0`, `CharImp:="Zpi"`, `RenormImp:="50ohm"`, plus `ShowReporterFilter:=False`, `ReporterFilter:=Array(True)`, `Impedance:="50ohm"`.

Original port 1 is a circular sheet in `slot_feed_td`, centre `(-positionx+slot_feed_w+h2,0,-h3_slot_feed-h_cabin)`, radius `r_cabmid`. In Global, its centre is `(-x_feed-positionx+slot_feed_w+h2,0,z_feed-h3_slot_feed-h_cabin)`. Source integration positions are attached to the outer port-circle edge and inner-conductor edge; edge numbers are not portable. A valid reconstructed line must run radially between the outer-conductor inner radius `r_cabmid` and inner-conductor radius `r_cabin` at that Z plane. The builder's source-linked ray and its transformed port-2 ray require HFSS runtime validation; rotational symmetry alone does not verify sign conventions of the exported complex S parameters.

`Solutions.EditSources` takes one array whose first element is `[IncludePortPostProcessing:=False,SpecifySystemPower:=False]` (False follows the reference model; the official v0.4.0 wrapper example uses True), followed by source blocks `[Name:="1:1",Magnitude:="1W",Phase:="0deg"]` and `[Name:="2:1",Magnitude:="0W",Phase:="0deg"]`. Switch the magnitudes to excite only port 2. Sources change field postprocessing; both ports stay present for the modal network solve.

`oDesign.ValidateDesign(validationLogPath)` returns integer **1 on success, 0 on failure**, documented in official v0.4.0 `Design.validate_simple`. A nonexception or a generated script is not a pass. Query expected named objects, both port assignments and setup/sweep presence too; log HFSS messages.

## Far-field setup and real reports

`RadField.InsertInfiniteSphereSetup` is the official v0.5.0 and current method spelling; use the reference's `UseCustomRadiationSurface`, `CSDefinition:="Theta-Phi"`, `Polarization:="Linear"`, Theta/Phi start/stop/step, `UseLocalCS:=False`. The source's `NoArray` is a separate **RadField ArraySetup** state, not a sphere property. New single-element designs should stay in NoArray; never introduce an inferred `UseOption` argument inside sphere parameters. HFSS 2021 R2 execution must confirm this insertion method because accessible v0.4.0 had no far-field helper.

`ReportSetup.CreateReport(name, category, displayType, solution, context, families, components)` appears in official 2021-era source. Categories include `Modal Solution Data` and `Far Fields`. Modal rectangular report components are `X Component:="Freq"`, `Y Component:=Array("dB(S(1,1))",...)`; modal context is empty. Far-field context uses `Array("Context:=",sphereName)`, includes a solved frequency in families, and uses quantities such as `dB(RealizedGainTotal)` confirmed in the original model. Display types and 3D component keys must be checked on HFSS; report creation is allowed to fail explicitly when unavailable.

**A configured setup is not solved data.** `AnalysisSetup.GetSetups` / `GetSweeps` are configuration queries. In v0.4.0 `GetAllSolutionNames` is used only for HFSS 3D Layout; applying it blindly to plain HFSS is unsafe. Before reports, query:

```vb
ReportSetup.GetSolutionDataPerVariation("Modal Solution Data", _
 "Setup1 : Sweep", Array(), Array("Freq:=",Array("All")), Array("dB(S(1,1))"))
```

Require returned solution-data objects and nonempty `GetSweepValues("Freq",False)` / `GetRealDataValues(expression,False)`. Far-field/efficiency reports require their own successful data query with the appropriate category, sphere and frequency. Unsupported or absent radiation-efficiency/HPBW data must stay unavailable. `ReportSetup.ExportToFile(reportName,csvPath)` exports real report data. Require the file and actual data rows before showing a result. Never fill missing query results with zero traces.

## Remaining runtime acceptance

1. Windows MATLAB launch on installed HFSS **2021 R2**; verify version and COM calls.
2. Equation-surface and far-field insertion method availability on that release.
3. CAD connectivity, booleans, total thickness, single-element object inventory and transformed geometry bounds.
4. Two coordinate integration lines reaching their intended conductors; port assignment validation.
5. ValidateDesign returns1, project SaveAs completes, and saved project reopens.
6. User-triggered analysis produces modal sweep data; far-field reports use genuinely saved fields.
7. Generated reports/CSV and GUI asynchronous states reflect real completion, failures and no-data cases.

Until these run, report **script generated / pending HFSS validation**, not “Build Successful” or “Simulated”.

## Additional review findings and confirmed APIs

`oProject.GetDefinitionManager()` returns the project definition manager. Official v0.4.0 `Material.update` uses `GetProjectMaterialNames()` to determine project-local existence, then `EditMaterial(name,args)` or `AddMaterial(args)`; do not invent `DoesMaterialExist`. Define source EM properties explicitly for a new scratch project: aluminum permeability=1.000021, conductivity=38000000 S/m; copper permeability=0.999991, conductivity=58000000 S/m. The argument array starts `NAME:<name>`, `CoordinateSystemType:=Cartesian`, `BulkOrSurfaceType:=1`, with `Array("NAME:PhysicsTypes","set:=",Array("Electromagnetic"))` and scalar property keys. The official [v0.4.0 Material.py](https://raw.githubusercontent.com/ansys/pyaedt/v0.4.0/pyaedt/modules/Material.py) documents this serializer and API dispatch at lines1189–1202. `GetManager("Material").GetData(name)` can read the material definition. These changes belong only to the new project, never to an opened source before SaveAs.

`GetVertexIDsFromObject(name)` and `GetVertexPosition(id)` are supported in v0.4.0 `Primitives.py`. `oDesktop.GetProjectList()`, `SetActiveProject(name)`, and `OpenProject(path)` are supported in v0.4.0 `Design.py`. `GetFaceArea(faceID)` and `GetFaceCenter(faceID)` are supported; face-centre queries can fail on nonplanar faces. Use planar coax end-face areas/centres to check annular geometry; seam vertices alone are inadequate to infer a circular cylinder bounding box.

The official v0.4.0 `Analysis.available_variations.nominal` appends `<independentName>:=`, `Array("Nominal")` to the report family array for every independent variable. Use these nominal families for both data queries and CreateReport. Omitting them can select old solved variations. The GUI selected setup must exist, the complete expected frequency vector must be present, and all four Sij vectors must be numeric before labeling a sweep simulated. Check actual live design variable expressions when reusing an already-open project: disk metadata does not reflect unsaved user edits.

Radiation efficiency is an optional real-data probe. If the Antenna Parameters query is unsupported or has no valid numeric data, skip that report and log the reason. The source integration line azimuth is inferred from attached circular EdgeCenter positions; exact phase agreement still needs runtime acceptance. A fresh object inventory or a single cached S11 sample cannot establish it.


The official [v0.4.0 Mesh.py](https://raw.githubusercontent.com/ansys/pyaedt/v0.4.0/pyaedt/modules/Mesh.py), `assign_initial_mesh_from_slider`, calls `MeshSetup.InitialMeshSettings` with `NAME:MeshSettings`, nested `NAME:GlobalSurfApproximation` (`CurvedSurfaceApproxChoice:="UseSlider"`, `SliderMeshSettings:=5`), `GlobalCurvilinear/Apply`, and `GlobalModelRes/UseAutoLength`. The source reference supplies the exact mesh flag values; preserve those instead of relying on a machine preset. `oEditor.SetModelUnits Array("NAME:Units Parameter","Units:=","mm","Rescale:=",False)` is documented by v0.4.0 Modeler.py and belongs before scratch CAD.
