function dump_path = save_backend_dump(dump_dir, tag, RGB_gamma, RGB_gt_gamma, W_eff, G_LTM, x_lut, gamma_lut, meta)
% SAVE_BACKEND_DUMP  保存进入 UniPyr-JDE 前一步的完整中间态，方便后端独立快速仿真
    if ~exist(dump_dir, 'dir'), mkdir(dump_dir); end
    dump_name = sprintf('dump_%s_ISO%d_f%d.mat', tag, meta.iso, meta.frame_id);
    dump_path = fullfile(dump_dir, dump_name);
    save(dump_path, 'RGB_gamma', 'RGB_gt_gamma', 'W_eff', 'G_LTM', 'x_lut', 'gamma_lut', 'meta');
end