function Phased_Array_Vivaldi_GUI_Pro()
    % =====================================================================
    % TOOL GIAO DIỆN: TẠO MẢNG M x N, CÓ NHẬP KHOẢNG CÁCH & HIỂN THỊ ẢNH
    % =====================================================================
    
    % Khởi tạo cửa sổ GUI chính (Đã mở rộng chiều ngang ra 750)
    fig = uifigure('Name', 'Vivaldi Phased Array Builder Pro', 'Position', [100 100 750 560]);
    
    % --- KHU VỰC 1: ĐƯỜNG DẪN FILE ---
    pnlFile = uipanel(fig, 'Title', '1. Liên kết hệ thống', 'Position', [20 450 710 90]);
    uilabel(pnlFile, 'Position', [10 30 100 22], 'Text', 'File .aedt gốc:', 'FontWeight', 'bold');
    edtFilePath = uieditfield(pnlFile, 'text', 'Position', [110 30 490 22], 'Value', '');
    uibutton(pnlFile, 'push', 'Text', 'Chọn File', 'Position', [610 30 80 22], 'ButtonPushedFcn', @(btn,event) browseFile());

    % --- KHU VỰC 2: THÔNG SỐ QUÉT & TẠO MẢNG M x N ---
    pnlParams = uipanel(fig, 'Title', '2. Thiết lập thông số & Mảng', 'Position', [20 210 710 230]);
    
    % Cột nhập liệu bên trái
    uilabel(pnlParams, 'Position', [20 175 160 22], 'Text', 'Tần số hoạt động (GHz):', 'FontWeight', 'bold');
    edtFreq = uieditfield(pnlParams, 'numeric', 'Position', [190 175 90 22], 'Value', 18);
    
    uilabel(pnlParams, 'Position', [20 140 160 22], 'Text', 'Góc quét theta_0 (độ):', 'FontWeight', 'bold');
    edtAngle = uieditfield(pnlParams, 'numeric', 'Position', [190 140 90 22], 'Value', 30.0);
    
    % Ô NHẬP KHOẢNG CÁCH MỚI (Thay thế chữ tĩnh)
    uilabel(pnlParams, 'Position', [20 105 160 22], 'Text', 'Khoảng cách d_x (mm):', 'FontWeight', 'bold', 'FontColor', [0.85 0.33 0.1]);
    edtDx = uieditfield(pnlParams, 'numeric', 'Position', [190 105 90 22], 'Value', 22.0);
    
    uilabel(pnlParams, 'Position', [20 70 170 22], 'Text', 'Số phần tử hàng ngang (Y):', 'FontWeight', 'bold');
    edtNy = uieditfield(pnlParams, 'numeric', 'Position', [190 70 90 22], 'Value', 2);
    
    uilabel(pnlParams, 'Position', [20 35 170 22], 'Text', 'Số phần tử hàng dọc (X):', 'FontWeight', 'bold');
    edtNx = uieditfield(pnlParams, 'numeric', 'Position', [190 35 90 22], 'Value', 2);
    
    % Cột hiển thị kết quả tính toán ở giữa
    uilabel(pnlParams, 'Position', [310 140 100 22], 'Text', 'Bước sóng λ:');
    lblLamda = uilabel(pnlParams, 'Position', [400 140 100 22], 'Text', '- mm', 'FontWeight', 'bold', 'FontColor', 'b');
    
    uilabel(pnlParams, 'Position', [310 105 100 22], 'Text', 'Lệch pha α:');
    lblAlpha = uilabel(pnlParams, 'Position', [400 105 100 22], 'Text', '- deg', 'FontWeight', 'bold', 'FontColor', 'r');

    % KHU VỰC HIỂN THỊ ẢNH BÊN PHẢI
    imgBox = uiimage(pnlParams, 'Position', [490 40 200 160]); 
    uibutton(pnlParams, 'push', 'Text', 'Tải ảnh minh họa', 'Position', [535 15 110 22], 'ButtonPushedFcn', @(btn,event) browseImage());
    
    % --- KHU VỰC 3: NÚT ĐIỀU KHIỂN & TRẠNG THÁI ---
    btnRun = uibutton(fig, 'push', 'Text', 'TẠO MẢNG & CẤP NGUỒN HFSS', ...
        'Position', [250 120 250 50], 'BackgroundColor', [0.85 0.33 0.1], 'FontColor', 'w', ...
        'FontWeight', 'bold', 'FontSize', 14, 'ButtonPushedFcn', @(btn,event) runHFSS());
        
    lblStatus = uilabel(fig, 'Position', [20 70 710 40], 'Text', 'Trạng thái: Sẵn sàng...', ...
        'FontWeight', 'bold', 'FontColor', [0 0.5 0], 'WordWrap', 'on');

    % Hàm chọn file ảnh
    function browseImage()
        [imgFile, imgPath] = uigetfile({'*.png;*.jpg;*.jpeg', 'Image Files (*.png, *.jpg, *.jpeg)'}, 'Chọn ảnh minh họa');
        if isequal(imgFile, 0), return; end
        imgBox.ImageSource = fullfile(imgPath, imgFile);
    end

    % Hàm chọn file HFSS
    function browseFile()
        [file, path] = uigetfile('*.aedt', 'Chọn file HFSS Project');
        if isequal(file, 0), return; end
        edtFilePath.Value = fullfile(path, file);
    end

    function runHFSS()
        existingProjectFile = edtFilePath.Value;
        hfssExePath = 'D:\Program Files\AnsysEM\AnsysEM21.2\Win64\ansysedt.exe';
        
        if isempty(existingProjectFile)
            uialert(fig, 'Vui lòng nhấn nút "Chọn File" .aedt trước khi chạy!', 'Lỗi'); return;
        end
        
        % Lấy thông số từ giao diện
        f_op = edtFreq.Value;
        theta_0 = edtAngle.Value;
        d_x = edtDx.Value; % BÂY GIỜ LẤY TRỰC TIẾP TỪ Ô NHẬP LIỆU
        
        N_y = round(edtNy.Value);
        N_x = round(edtNx.Value);
        if N_y < 1, N_y = 1; end
        if N_x < 1, N_x = 1; end
        N = N_y * N_x; 
        
        c = 300; 
        lamda_val = c / f_op; 
        
        % Tính toán Alpha dựa trên d_x người dùng nhập
        alpha_val = -360 * (d_x / lamda_val) * sind(theta_0);
        
        % Cập nhật giao diện
        lblLamda.Text = sprintf('%.3f mm', lamda_val);
        lblAlpha.Text = sprintf('%.2f deg', alpha_val);
        
        % Tên file chuẩn: vivaldi_array_NyxNx_Freq_Angle
        [file_dir, ~, file_ext] = fileparts(existingProjectFile);
        newFileName = sprintf('vivaldi_array_%dx%d_%gGHz_%gdeg%s', N_y, N_x, f_op, theta_0, file_ext);
        newProjectFile = fullfile(file_dir, newFileName);
        
        lblStatus.Text = sprintf('Trạng thái: Đang tạo file mới "%s" và chạy mô phỏng...', newFileName); drawnow;

        try
            tmpScriptFile = fullfile(pwd, 'gui_build_array_pro.vbs');
            fid = fopen(tmpScriptFile, 'wt');
            
            fprintf(fid, 'On Error Resume Next\n\n');
            
            % [1] NẠP DỰ ÁN VÀ SAVE AS FILE MỚI
            fprintf(fid, 'Dim oAnsoftApp, oDesktop, oProject, oDesign, oEditor, oModule\n');
            fprintf(fid, 'Set oAnsoftApp = CreateObject("Ansoft.ElectronicsDesktop")\n');
            fprintf(fid, 'Set oDesktop = oAnsoftApp.GetAppDesktop()\n');
            fprintf(fid, 'oDesktop.RestoreWindow\n');
            fprintf(fid, 'oDesktop.OpenProject "%s"\n', existingProjectFile);
            fprintf(fid, 'Set oProject = oDesktop.GetActiveProject()\n');
            fprintf(fid, 'oProject.SaveAs "%s", true\n', newProjectFile);
            fprintf(fid, 'Set oDesign = oProject.GetActiveDesign()\n');
            fprintf(fid, 'Set oEditor = oDesign.SetActiveEditor("3D Modeler")\n\n');
            
            % [2] CẬP NHẬT BIẾN THIẾT KẾ VÀ BIẾN ALPHA
            fprintf(fid, 'oDesign.SetVariableValue "lamda", "%.4fmm"\n', lamda_val);
            fprintf(fid, 'oDesign.SetVariableValue "scan_theta", "%.4fdeg"\n', theta_0);
            fprintf(fid, 'oDesign.SetVariableValue "alpha", "%.4fdeg"\n\n', alpha_val);
            
            % [3] TẠO MẢNG HÌNH HỌC THEO KHOẢNG CÁCH MỚI
            fprintf(fid, 'Dim objs, obj, selStr\n');
            
            if N_y > 1
                fprintf(fid, 'objs = oEditor.GetMatchedObjectName("*")\n');
                fprintf(fid, 'selStr = ""\n');
                fprintf(fid, 'For Each obj In objs\n');
                fprintf(fid, '  If InStr(1, obj, "RadiatingSurface", 1) = 0 And InStr(1, obj, "Box", 1) = 0 Then\n');
                fprintf(fid, '    If selStr = "" Then selStr = obj Else selStr = selStr & "," & obj\n');
                fprintf(fid, '  End If\n');
                fprintf(fid, 'Next\n');
                
                % Lệnh nhân bản Y sử dụng biến số thay vì giá trị cứng
                fprintf(fid, 'oEditor.DuplicateAlongLine Array("NAME:Selections", "Selections:=", selStr, "NewPartsModelFlag:=", "Model"), _\n');
                fprintf(fid, '  Array("NAME:DuplicateToAlongLineParameters", "CreateNewObjects:=", true, "XComponent:=", "0mm", "YComponent:=", "%.4fmm", "ZComponent:=", "0mm", "NumClones:=", %d), _\n', d_x, N_y);
                fprintf(fid, '  Array("NAME:Options", "DuplicateAssignments:=", true, "DuplicateMeshOperations:=", true)\n\n');
            end
            
            if N_x > 1
                fprintf(fid, 'objs = oEditor.GetMatchedObjectName("*")\n');
                fprintf(fid, 'selStr = ""\n');
                fprintf(fid, 'For Each obj In objs\n');
                fprintf(fid, '  If InStr(1, obj, "RadiatingSurface", 1) = 0 And InStr(1, obj, "Box", 1) = 0 Then\n');
                fprintf(fid, '    If selStr = "" Then selStr = obj Else selStr = selStr & "," & obj\n');
                fprintf(fid, '  End If\n');
                fprintf(fid, 'Next\n');
                
                % Lệnh nhân bản X sử dụng biến số
                fprintf(fid, 'oEditor.DuplicateAlongLine Array("NAME:Selections", "Selections:=", selStr, "NewPartsModelFlag:=", "Model"), _\n');
                fprintf(fid, '  Array("NAME:DuplicateToAlongLineParameters", "CreateNewObjects:=", true, "XComponent:=", "%.4fmm", "YComponent:=", "0mm", "ZComponent:=", "0mm", "NumClones:=", %d), _\n', d_x, N_x);
                fprintf(fid, '  Array("NAME:Options", "DuplicateAssignments:=", true, "DuplicateMeshOperations:=", true)\n\n');
            end
            
            % [4] VIẾT LỆNH EDIT SOURCES 
            fprintf(fid, 'Set oModule = oDesign.GetModule("Solutions")\n');
            fprintf(fid, 'oModule.EditSources Array( _\n');
            fprintf(fid, '  Array("IncludePortPostProcessing:=", true, "SpecifySystemPower:=", false)');
            
            for i = 1:N
                col_idx = i - 1;
                
                if col_idx == 0
                    phase_str = '0deg';
                elseif col_idx == 1
                    phase_str = 'alpha';
                else
                    phase_str = sprintf('alpha*%d', col_idx);
                end
                
                p1 = sprintf('%d:1', 2*i - 1); 
                p2 = sprintf('%d:1', 2*i);     
                
                fprintf(fid, ', _\n  Array("Name:=", "%s", "Magnitude:=", "1W", "Phase:=", "%s")', p1, phase_str);
                fprintf(fid, ', _\n  Array("Name:=", "%s", "Magnitude:=", "0W", "Phase:=", "0deg")', p2);
            end
            fprintf(fid, ')\n\n');
            
            % [5] LƯU VÀ CHẠY
            fprintf(fid, 'oProject.Save\n');
            fprintf(fid, 'oDesign.AnalyzeAll\n'); 
            fclose(fid);
            
            lblStatus.Text = 'Trạng thái: Đang chạy kịch bản... Hãy quan sát cửa sổ HFSS nhé!'; drawnow;
            
            % Lệnh chạy background đã gắn dấu &
            system(['"', hfssExePath, '" /RunScript "', tmpScriptFile, '" &']);
            
            lblStatus.Text = sprintf('HOÀN THÀNH! Đã lưu thành "%s" và đang chạy mô phỏng HFSS.', newFileName);
            lblStatus.FontColor = [0 0.5 0];
            
        catch ME
            lblStatus.Text = ['LỖI: ' ME.message];
            lblStatus.FontColor = 'r';
        end
    end
end