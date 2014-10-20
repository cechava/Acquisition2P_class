function motionCorrect(obj,writeDir,motionCorrectionFunction)
    %Generic wrapper function for managing motion correction of an
    %acquisition object
    
%% Error checking and input handling    
    if ~exist('motionCorrectionFunction', 'var')
        motionCorrectionFunction = [];
    end
    
    if isempty(motionCorrectionFunction) && isempty(obj.motionCorrectionFunction)
        error('Function for correction not provided as argument or specified in acquisition object');
    elseif isempty(motionCorrectionFunction)
        motionCorrectionFunction = obj.motionCorrectionFunction;
    elseif isempty(obj.motionCorrectionFunction)
        obj.motionCorrectionFunction = motionCorrectionFunction;
    end
    
    if isempty(obj.acqName)
        error('Acquisition Name Unspecified'),
    end
        
    if ~exist('writeDir', 'var') || isempty(writeDir) %Use Corrected in Default Directory if non specified
        if isempty(obj.defaultDir)
            error('Default Directory unspecified'),
        else
            writeDir = [obj.defaultDir filesep 'Corrected'];
        end
    end
    
    if isempty(obj.motionRefMovNum)
        error('Motion Correction Channel not identified');
    end
    
%% Load movies and motion correct
    %Calculate Number of movies and arrange processing order so that reference is first
    nMovies = length(obj.Movies);
    if isempty(obj.motionRefMovNum)
        obj.motionRefMovNum = floor(nMovies/2);
    end
    movieOrder = 1:nMovies;
    movieOrder([1 obj.motionRefMovNum]) = [obj.motionRefMovNum 1];
    
    %Load movies one at a time in order, apply correction, and save as
    %split files (slice and channel)
    for movNum = movieOrder
        fprintf('\nLoading Movie #%03.0f of #%03.0f\n',movNum,nMovies),
        [mov, scanImageMetadata] = obj.readRaw(movNum,'single');
        if obj.binFactor > 1
            mov = binSpatial(mov, obj.binFactor);
        end
        
        % Apply line shift:
        fprintf('Line Shift Correcting Movie #%03.0f of #%03.0f\n', movNum, nMovies),
        mov = correctLineShift(mov);
        [movStruct, nSlices, nChannels] = parseScanimageTiff(mov, scanImageMetadata);
        clear mov
        
        % Find motion:
        fprintf('Identifying Motion Correction for Movie #%03.0f of #%03.0f\n', movNum, nMovies),
        obj.motionCorrectionFunction(obj, movStruct, scanImageMetadata, movNum, 'identify');
        
        % Apply motion correction:
        fprintf('Applying Motion Correction for Movie #%03.0f of #%03.0f\n', movNum, nMovies),
        movStruct = obj.motionCorrectionFunction(obj, movStruct, scanImageMetadata, movNum, 'apply');
        for nSlice = 1:nSlices
            for nChannel = 1:nChannels
                movFile = sprintf('%s_Slice%02.0f_Channel%02.0f_File%03.0f.tif', obj.acqName, nSlice, nChannel, movNum);
                obj.correctedMovies.slice(nSlice).channel(nChannel).fileName{movNum} = fullfile(writeDir,movFile);
                fprintf('Writing Movie #%03.0f of #%03.0f\n',movNum,nMovies),
                tiffWrite(movStruct.slice(nSlice).channel(nChannel).mov,movFile,writeDir,16);
            end
        end
        
    end
    
    eval([obj.acqName ' = obj;']),
    save(fullfile(writeDir, obj.acqName), obj.acqName)
    display('Motion Correction Completed!')