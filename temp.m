% Script for running the Austenite reconstruction algorithm
% NOTE: all the comments here are NOT for final release, they are just
% either personal reminders, or Notes for/by Austin/Steve.

%============================================
% Flight Check
%============================================
clear all
close all
% Change this line or everything breaks
Aus_Recon_Parent_folder = "C:\Users\agerlt\workspace\Aus_Recon";
% make struct of where things are 
meta.Data_folder = Aus_Recon_Parent_folder + filesep + 'EBSD\AF96_321x';
meta.MTEX_folder = Aus_Recon_Parent_folder + filesep + 'MTEX';
meta.Functions_folder = string(pwd) + filesep + 'Functions';
meta.current_folder = string(pwd);
meta.MTEX_Version = "mtex-5.7.0";
addpath(genpath(meta.Functions_folder));
check_AusRecon_loaded;
try
    disp(['Compatable MTEX version ', check_MTEX_version(meta.MTEX_Version), ' detected'])
catch
    disp('Incompatable or missing version of MTEX.')
    disp('Attempting to load local copy ... ')
    addpath(meta.MTEX_folder + filesep + meta.MTEX_Version);
    startup_mtex
end
clear Aus_Recon_Parent_folder

%============================================
% Setting up Recon Jobs
%============================================
%%%%%%%   Load options  %%%%%%%%
% when we run AusRecon, we pass around a LOT of options that have had a
% habit of getting hard-coded into places they shouldn't be. instead,
% Lets just make an options structure, where people can load a default,
% alter what they want, then save their own defaults
options = load_options("default");
% Can load other options like this:
options = load_options("debug");
% then change default values once loaded like this:
options.OR_ksi = [3.09,8.10,8.48];
options.OR_noise = 1.7*degree;
% or create multiple option structures for different expected jobs, or edit
% them on the fly in a for loop, or whatever else. For now, delete and load
% defaults (no given OR, no auto_OR plots, no txt_out, no segmentation)
clear options
options = load_options();

% Options should NOT be edited by any following default functions. Also,
% metadata should NOT be written to it; that belongs in the EBSD struct,
% similar to how grain size is done in MTEX

%%%%%%%   Create task list of EBSD scans  %%%%%%%%
% Make a list of the EBSD text files you want to run through AusRecon
fnames = dir(meta.Data_folder + '\'+'*.ang');
fnames = fnames(1:5);
% Use that list to make a non-scalar struct object for where files are, what
% they are named, which options file to use, and recording what stage they
% made it to before exiting (change as needed)
for i = 1:length(fnames)
    name = split(string(fnames(i).name),'.');
    Tasks(i).name  = name(end-1);
    Tasks(i).location = [fnames(i).folder, filesep, fnames(i).name];
    Tasks(i).options = options;
    Tasks(i).stage = 0;
end

% remove persistant variables
clear name i options fnames data_foldername;
%============================================
% Pre-Recon Setup
%============================================
%%%%%%%   Load scans into MTEX EBSD structures  %%%%%%%%
% NOTE: For now, I am storing the EBSD objects in the Tasks struct. THIS IS
% A REALLY BAD PRACTICE FOR LARGE TESTS!!! DO NOT COPY THIS!!!!!!! This is
% for DEBUGGING. Normally, you save these ebsd objects as .mat or .txt
for i = 1:length(Tasks)
    % NOTE: at this point, there are just too many ebsd files to generalize
    % a loading step. this code assumes you find a method for loading your
    % files using MTEX. here is a link to a good starting point:
    % https://mtex-toolbox.github.io/EBSDImport.html
    % let users choose how they want to import the ebsd with the MTEX
    % loader. Trying to predict every possible fringe scenario is a suckers
    % game (both Alex and I wasted literal weeks on this)
    original_ebsd =  EBSD.load(Tasks(i).location,...
        'convertEuler2SpatialReferenceFrame'...
        ,'setting 2');
    % NOTE: if the command above gives results that you cannot easily align
    % with the old examples, here is the older (but maybe less correct? way
    % to load them):
    %original_ebsd =  EBSD.load(Tasks(i).location,'wizard')

    %%%%%%%   SECOND MAJOR PROBLEM FUNCTION   %%%%%%%%
    % EBSD files come in all shapes and sizes. We need to make a single style
    % where we say which phase is parent, which is child, and fix the ordering
    % of them.
    reformatted_ebsd = prep_for_Recon(original_ebsd,Tasks(i).options);
    Tasks(i).ebsd = reformatted_ebsd;
    Tasks(i).stage = 1;
end
clear original_ebsd reformatted_ebsd i

% at this point, we have identical scans with the following phase IDs:
%-1 : Unindexed
% 1 : Untransformed Parent (High temperature, or HT)
% 2 : Transformed Child (Low Temperature, or LR)
% 3 : Reconstructed Parent (starts empty) (Reconstructed, or R)

%============================================
% DETERMINING ORIENTATION RELATIONSHIP AND CALCULATING THE LT_MDF
%============================================
for i = 1:length(Tasks)
    CS_HT =Tasks(1).ebsd.CSList{1};
    CS_LT =Tasks(2).ebsd.CSList{1};
    try
        % First calculate the correct OR and HW
        % NOTE: ask steve for why the HW is calculated during this step
        [OR,HW,metadata] = AutoOR_estimation(Tasks(i).ebsd,Tasks(i).options);
        Tasks(i).ebsd.opt.OR = OR;
        Tasks(i).ebsd.opt.HW = HW;
        Tasks(i).OR_metadata = metadata;
        %    Tasks(i).ebsd.opt.OR_metadata = metadata;
        % Use those values to find the MDF which will be used for populating the
        % out of plane weights
        [LT_MDF,psi] = calc_LT_MDF(CS_HT, CS_LT, ...
            Tasks(i).ebsd.opt.HW,...
            Tasks(i).ebsd.opt.OR);
        Tasks(i).ebsd.opt.LT_MDF = LT_MDF;
        Tasks(i).ebsd.opt.psi = psi;
    catch
        disp('beans!!!')
    end
end
clear psi OR metadata M LT_MDF i HW
%%

% ===== Restart from here for Recon Troubleshooting ===== %
clear all
close all
load Post_OR.mat
% reset options in case they change
for i = 1:length(Tasks)
    Tasks(i).options = load_options;
end

%============================================
% PRIOR AUSTENITE RECONSTRUCTION
%============================================
for i = 1:length(Tasks)
    % THIS NEEDS A MAJOR REWRITE. No one seems to know how it works, and I
    % am positive it takes longer than needed. I want to write this one out
    % on the board to discuss if possible
    % Pre-calculate adjacency matrix
    % BIG NOTE HERE: FOR SOME REASON, the original code uses not just
    % neighbors, but neighbors of neighbors in their code (IE,1st through
    % 3rd 2D Von Neumann neighborhoods). This SEEMS like it should be
    % wrong, as it isnt a typical adjacency array A, but the equivilant of 
    % A +(A*A). It would also slow down the graph cut by a factor of 4x or 
    % so. HOWEVER, for some reason it works, so I'm keeping it in the code
    % here. to switch to only 1st nearest (IE, only 1st Von Neumann
    % neighborhood) change the 12 to a 4 in the function call below.
    A = calculate_adjacency_matrix(Tasks(i).ebsd,12);
    Tasks(i).Recon_ebsd = Call_Reconstruction(Tasks(i).ebsd,Tasks(i).ebsd.opt.LT_MDF,A);
end

%============================================
% VARIANT SEGMENTATION
%============================================
segmented_ebsds = {};
for i = length(Fnames)
    % THIS ALSO NEEDS A MAJOR REWRITE. I have spent easily 100 hours trying
    % to understand this function, we need to just state out loud what it
    % does and how it does it, and write it out on the board as well
    segmented_ebsds{i} = ReconstructAuto_OR_estimation(recon_ebsds{i});
end

%============================================
% Done
%============================================
% Time to go get lunch




