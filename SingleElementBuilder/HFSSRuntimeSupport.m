classdef HFSSRuntimeSupport
    % HFSSRUNTIMESUPPORT Shared path discovery and explicit UTF-16 file I/O.
    methods (Static)

        function files = findExecutables(roots, recursive)
            if nargin < 2
                recursive = true;
            end
            if nargin < 1 || isempty(roots)
                files = {};
                if ~ispc
                    return
                end
                roots = {getenv('ANSYSEM_ROOT212'), getenv('ANSYSEM_ROOT'), ...
                         getenv('ProgramFiles'), getenv('ProgramFiles(x86)'), ...
                         'C:\Program Files', 'D:\Program Files'};
            end
            files = {};
            for k = 1:numel(roots)
                root = char(roots{k});
                if isempty(root) || ~isfolder(root)
                    continue
                end
                candidates = {fullfile(root, 'ansysedt.exe'), ...
                              fullfile(root, 'Win64', 'ansysedt.exe'), ...
                              fullfile(root, 'AnsysEM21.2', 'Win64', 'ansysedt.exe'), ...
                              fullfile(root, 'AnsysEM', 'AnsysEM21.2', 'Win64', 'ansysedt.exe'), ...
                              fullfile(root, 'ANSYS Inc', 'v212', 'AnsysEM', 'Win64', 'ansysedt.exe')};
                for j = 1:numel(candidates)
                    if isfile(candidates{j})
                        files{end + 1} = candidates{j}; %#ok<AGROW>
                    end
                end
                if recursive
                    patterns = {fullfile(root, 'AnsysEM', '**', 'ansysedt.exe'), ...
                                fullfile(root, 'ANSYS Inc', '**', 'ansysedt.exe')};
                    for j = 1:numel(patterns)
                        found = dir(patterns{j});
                        for n = 1:numel(found)
                            files{end + 1} = fullfile(found(n).folder, found(n).name); %#ok<AGROW>
                        end
                    end
                end
            end
            files = unique(files, 'stable');
        end

        function exe = resolveExecutable(exe)
            if isstring(exe) && isscalar(exe)
                exe = char(exe);
            end
            assert(ischar(exe) && (isrow(exe) || isempty(exe)), ...
                   'Vivaldi:ExecutablePath', 'Executable path must be scalar text.');
            exe = strtrim(exe);
            if numel(exe) >= 2 && exe(1) == '"' && exe(end) == '"'
                exe = exe(2:end - 1);
            end
            if isempty(exe)
                found = HFSSRuntimeSupport.findExecutables([], false);
                if isempty(found) && ispc
                    found = HFSSRuntimeSupport.findExecutables();
                end
                if ~isempty(found)
                    exe = found{1};
                end
            end
            [~, name, extension] = fileparts(exe);
            reference = 'D:\Program Files\AnsysEM\AnsysEM21.2\Win64\ansysedt.exe';
            assert(isfile(exe) && strcmpi([name extension], 'ansysedt.exe'), ...
                   'Vivaldi:ExecutableNotFound', ...
                   ['Không tìm thấy ansysedt.exe tại "%s". Chọn Browse hoặc Auto-detect. ' ...
                    'Đường dẫn tham khảo: %s. Chế độ chỉ sinh VBScript không cần cài Ansys.'], ...
                   exe, reference);
            [ok, attributes] = fileattrib(exe);
            assert(logical(ok), 'Vivaldi:ExecutablePath', 'Không đọc được executable.');
            exe = attributes.Name;
        end

        function writeUTF16(file, text)
            fid = fopen(file, 'wb');
            assert(fid >= 0, 'Vivaldi:ScriptWrite', 'Không ghi được %s.', file);
            cleanup = onCleanup(@()fclose(fid)); %#ok<NASGU>
            bytes = [uint8([255 254]) unicode2native(char(text), 'UTF-16LE')];
            count = fwrite(fid, bytes, 'uint8');
            assert(count == numel(bytes), 'Vivaldi:ScriptWrite', 'Ghi script không đầy đủ.');
        end

        function text = readUTF16(file)
            fid = fopen(file, 'rb');
            assert(fid >= 0, 'Vivaldi:StatusRead', 'Không đọc được %s.', file);
            cleanup = onCleanup(@()fclose(fid)); %#ok<NASGU>
            bytes = fread(fid, Inf, '*uint8')';
            if numel(bytes) >= 2 && isequal(bytes(1:2), uint8([255 254]))
                bytes = bytes(3:end);
            end
            % A status file can be read while the writer is between two bytes.
            bytes = bytes(1:2 * floor(numel(bytes) / 2));
            text = native2unicode(bytes, 'UTF-16LE');
        end

    end
end
