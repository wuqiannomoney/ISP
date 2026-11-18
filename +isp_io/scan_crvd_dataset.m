function items = scan_crvd_dataset(crvd_root)
% SCAN_CRVD_DATASET  扫描 CRVD 目录，解析每个场景/ISO/帧及对应的 clean/gt 路径
    noisy_files = dir(fullfile(crvd_root, '**', '*_noisy*.tiff'));
    if isempty(noisy_files)
        error('在目录 %s 下未找到 *_noisy*.tiff 文件，请检查路径！', crvd_root);
    end

    % 修复方案：先初始化空数组，而不是用 struct() 构造函数
    items = []; 

    idx = 0;
    for k = 1:numel(noisy_files)
        f_dir  = noisy_files(k).folder;
        f_name = noisy_files(k).name;
        full_p = fullfile(f_dir, f_name);

        % 解析 ISO 值
        tok_iso = regexp(full_p, 'ISO(\d+)', 'tokens', 'once');
        if isempty(tok_iso), continue; end
        iso_val = str2double(tok_iso{1});

        % 解析 scene、frame 和 noisy 编号
        tok_sc = regexp(full_p, '(scene\d+)', 'tokens', 'once');
        if isempty(tok_sc), sc_name = 'scene0'; sc_id = 0;
        else, sc_name = tok_sc{1}; sc_id = str2double(regexp(sc_name, '\d+', 'match', 'once')); end

        tok_fn = regexp(f_name, 'frame(\d+)_noisy(\d+)', 'tokens', 'once');
        if isempty(tok_fn), continue; end
        fr_id = str2double(tok_fn{1});
        ns_id = str2double(tok_fn{2});

        % 查找同目录下的 clean.tiff
        clean_p = fullfile(f_dir, sprintf('frame%d_clean.tiff', fr_id));
        if ~exist(clean_p, 'file'), clean_p = ''; end

        % 查找 indoor_raw_gt 目录
        gt_p = strrep(f_dir, 'indoor_raw_noisy', 'indoor_raw_gt');
        gt_file = fullfile(gt_p, sprintf('frame%d_clean_and_slightly_denoised.tiff', fr_id));
        if ~exist(gt_file, 'file'), gt_file = clean_p; end

        idx = idx + 1;
        % 直接给结构体数组赋值
        items(idx).noisy_path    = full_p;
        items(idx).clean_path    = clean_p;
        items(idx).gt_path       = gt_file;
        items(idx).iso           = iso_val;
        items(idx).scene_id      = sc_id;
        items(idx).frame_id      = fr_id;
        items(idx).noisy_id      = ns_id;
        items(idx).scene_name    = sc_name;
        items(idx).bayer_pattern = 'gbrg';
        items(idx).bl            = 240;
        items(idx).wl            = 4095;
    end

    % 按 ISO 排序
    if ~isempty(items)
        T = struct2table(items);
        [~, order] = sortrows(T, {'iso', 'scene_id', 'noisy_id', 'frame_id'});
        items = items(order);
    end
end