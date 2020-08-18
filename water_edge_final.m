%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%               Water level pixel location extractor                      %
%               Author: Jonathan Reshef, Abhi Ramesh (source code)        %
%               Date: 13 Febuar 2018                                      %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
clear
clc

%{
This function finds the intersect between the water edge and a structure by
tracking the movement of the water relative to the vertical position of hte
structure. For this to work it requires that there is a high level of
contrast between the object and the fluid. It also requires that the video
includes the water BEFORE the wave is generated so that a default position
of the water and structure can be found.
%}

%set the name of the file to be analysed
%if multiple versions of the .mov file exist in the same directory 
%(ie if test1, test2 etc.) then set common_name to be test
%common_name = 'H_test1.mov'; %set the common name of the files

%set the directory of the video/s to be analysed
%video_dir = '/Volumes/Storage/Vidoes/FINZ_videos/';

common_name = 'Light_freemoving_tiedown.mov'; %set the common name of the files

%set the directory of the video/s to be analysed
video_dir = '/Volumes/Storage/Vidoes/Extra_Tests/';

%load the first video in the directory to be used for UI input --> for
%processing multiple videos of different versions, this works ONLY if the
%camera set up doesn't change. If the set up changes then a new UI for the
%ROI to be analysed will be needed
dir_FINZ = dir(strcat(video_dir, common_name, '*'));
dir_FINZ = {dir_FINZ.name};

mode = 0; %re-calculates the vertical intersect for a moving structure
%mode = 1; %assumes stationary object
%mode = 2; %calculates the maximum height for object run up

%% UI input for the video

%assume the first video is representative of all the videos in the
%directory of the same common name
video = VideoReader(strcat(video_dir, dir_FINZ{1}));
[outline_thick, area, xy, x_s, len] = UI_vid(video);

%% Processing the videos based on the settings chosen above

for i = 1:length(dir_FINZ)
    
    %process the selected video
    video = VideoReader(strcat(video_dir, dir_FINZ{i})); %#ok<TNMLP>
    
    %depending on which mode selected, set the video processing function
    if mode == 0 %moving object
        [pos, mov, mov2] = MovingObject(video, outline_thick, area, xy);

    elseif mode == 1 %stationary object
        [pos, mov] = StationaryObject(video, outline_thick, area, xy);

    elseif mode == 2 %sloping object
        [pos, mov] = SlopingObject(video, outline_thick, area, xy, x_s);
    end
    
    %for naming purposes, just select the name without file ext
    [~, name] = fileparts(dir_FINZ{i});
    
    %plot of detected height
    figure();set(gcf,'Visible', 'off');
    fig = plot(linspace(0, video.Duration, video.NumberOfFrames), (pos(1, 2) - pos(:, 2))/len); %#ok<*VIDREAD>
    title('Position of water level')
    ylabel('Height above starting position (cm)')
    xlabel('Time (secs)')
    
    %save the created figure in the directory of the video
    saveas(fig, strcat(video_dir, name, "_plot.jpg"))
    
    %save the generated movie of the height detection
    v = VideoWriter(strcat(video_dir, name, 'processed')); %#ok<TNMLP>
    v.FrameRate = 120;
    open(v);
    writeVideo(v, mov);
    close(v)
    
    %{
    %save the generated movie of the edges detected
    v2 = VideoWriter(strcat(video_dir, name, 'edge_detection')); %#ok<TNMLP>
    v2.FrameRate = 120;
    open(v2);
    writeVideo(v2, mov2);
    close(v2)
    %}
    
    %display the percent of frames with an intersect discovered  
    sprintf('%.2f%% frames found with intersects',100*(1-sum(isnan(pos(:, 1))/video.NumberOfFrames)))
end