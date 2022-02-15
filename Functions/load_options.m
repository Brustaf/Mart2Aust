function options_struct = load_options(preset)
%UNTITLED2 Summary of this function goes here
%   Detailed explanation goes here
options_struct = load_default_options();
if ~exist('preset','var')
else
    preset = string(preset);
    if preset == "default"
    elseif preset == "debug"
        options_struct = steel_debug_opt(options_struct);
    elseif preset == "test"
        options_struct = steel_test_opt(options_struct);
    end
end
end

function options_struct = steel_debug_opt(options_struct)
%UNTITLED2 Summary of this function goes here
%   Detailed explanation goes here
options_struct.OR_plot_mart = 1;
options_struct.OR_plot_vars = 1;
options_struct.OR_plot_ksi_spread = 1;
end

function options_struct = steel_test_opt(options_struct)
%UNTITLED2 Summary of this function goes here
%   Detailed explanation goes here
options_struct.calc_grain_metrics = 0;
options_struct.variant_segmentation = 0;
options_struct.calc_variant_metrics = 0;
options_struct.plot_packets = 0;
options_struct.plot_blocks = 0;
options_struct.plot_variants = 0;
options_struct.output_text_file = 0;
end

function options_struct = load_default_options()
%UNTITLED2 Summary of this function goes here
%   Detailed explanation goes here
options_struct = struct(...
    ...% Material
    'material', 'Steel', ...
    'specimen_symmetry', 'triclinic', ...
... High Temperature Phase (Austenite in Steel)
    'High_Temp_phase_name', 'Austenite', ...
    'High_Temp_phase_color', str2rgb('LightGreen'), ...
    'High_Temp_phase_symm', 'm-3m', ...
... Low Temperature Phase (Martensite in Steel)
    'Low_Temp_phase_name', 'Martensite', ...
    'Low_Temp_phase_color', str2rgb('DarkRed'), ...
    'Low_Temp_phase_symm', 'm-3m', ...
... Name for Reconstructed phase (identical CS to high temp phase)
    'Reconstructed_phase_name', 'Recon_Austenite', ...
    'Reconstructed_phase_color', str2rgb('DarkBlue'), ...
... Orientation Relationship Information
    'OR_ksi', [0, 0, 0], ...
    'OR_noise', 0, ...
    'OR_sampling_size', 2000, ...
... AutoOR plotting information
    'OR_plot_PAG_Mart_Guess', 0, ...
    'OR_plot_ODF_of_PAG_OR_guess', 0, ...
    'OR_plot_ksi_spread', 0, ...
... Reconstruction Graph Cut Parameters
    'RGC_in_plane_m', 3, ...
    'RGC_in_plane_b', 12, ...
    'RGC_post_pre_m', 0.175, ...
    'RGC_post_pre_b', 0.35, ...
    'degree_of_connections_for_neighborhood', 1, ...
    'min_cut_size',5,...
    'max_recon_attempts',500,...
... Post Recon options
    'calc_grain_metrics', 1, ...
    'variant_segmentation', 1, ...
    'calc_variant_metrics', 1, ...
    'plot_packets', 1, ...
    'plot_blocks', 1, ...
    'plot_variants', 1, ...
    'output_text_file', 1);
end
