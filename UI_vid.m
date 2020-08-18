function[outline_thick, area, xy, x_s, len] = UI_vid(video)

    %{
    This function takes a video and allows the user to select the ROI and
    define the impact zone. 

    Tips to improve processing ability:
        -Make the ROI as small as possible so that the contrast enhancements
        work better + makes it faster
        -Try to black out areas that are very different in contrast from
        the whole image during the final check
        -When selecting the area behind the structure, if it is stationary
        (ie mode 0 or 2) try to outline the structure as closely as
        possible
    %}

    %find the pixel to unit conversion
    figure
    cond = 1;
    while cond
        try %UI for selecting ruler length
            img_d = read(video, 1);
            imshow(img_d)
            title('Draw the line between the units of the ruler. If no conversion needed close the window.');
            line = drawline;
            line_p = line.Position;
            
            %give user option to specify the length of the line drawn, note
            %that the length of the line drawn is used, not just the
            %vertical component
            d = input("What is the length (cm) of the ruler between the points drawn: ");
            width = max(line_p(:, 1))-min(line_p(:, 1)); %width of line
            height = max(line_p(:, 2))-min(line_p(:, 2)); %height of line
            len = sqrt(width^2 + height ^2)/d; %length of line
            close
            cond = 0;
        catch %if no ruler needed and window closed then display graphs as pixel units
            len = 1;
            close
            cond = 0;
        end
    end
   
    %select a rectangular area for analysis
    figure
    img0 = read(video, 1);
    imshow(img0)
    title('Select the area of interest for wave tracking');
    area = getrect;
    
    %get the dimensions of the image
    [y_img, x_img, ~] = size(imcrop(img0, area));

    %draw approximately the area of behind the structure
    cond = 1;
    

    img1 = imcrop(img0, area);
    imshow(img1, 'InitialMagnification', length(img0)/length(img1)*100)
    title('Approximately indicate the area inside and behind the structure');

    %x and y are describing the co-ordinates of the points of the area
    %behind the structure, xy is the matrix of the selected area
    [xy, ~, ~] = roipoly();
    cond = 0;
    close
    
    if isempty(xy) %if no area behind the structure is selected, set all to true
        xy = ones(y_img, x_img);
    else %if an area is selected, set the selected area to false
        xy = ~xy;
    end
    
   

    %create a cropped image of the area for further user refinement --> the
    %goal is to remove the HORIZONTAL edges detected
    cond = 1;

    while cond == 1
        try
            %Display and allow user to further remove area behind the
            %structure using rectange tool --> goal is to ensure that there
            %is at least a continuous vertical area removed behind the
            %structure so no horizontal edges are deteected
            img2 = imadjust(rgb2gray(imcrop(read(video, 1), area).* uint8(xy)), [0; 0.5], [0; 1]);
            imshow(img2, 'InitialMagnification', length(img0)/length(img2)*100)
            title({'Final check. Remove as much of the boundary around the structure as possible. The goal is to remove all possible horizontal edges', 'When complete close the window'});

            %convert the rectangle dimensions selected into int
            a = int64(getrect);

            %store the indices of the rectangle
            pos_s2 = {a(2):(a(2)+a(4)) a(1):(a(1)+a(3))};

            %ensure the indices are within the boundary of the image
            pos_s2{1}(pos_s2{1}<1) = 1;
            pos_s2{2}(pos_s2{2}<1) = 1;
            pos_s2{1}(pos_s2{1}>y_img) = y_img;
            pos_s2{2}(pos_s2{2}>x_img) = x_img;

            %set the selected area to be black
            xy(pos_s2{1}, pos_s2{2}) = 0;

        catch
            %when finished selecting the areas, close the image and finish
            %the loop
            close
            cond = 0;
        end

    end

    %% Finding the intersect
    %indicate approximately where the waterline intersects the
    %structure
    %img2 = rgb2gray(imcrop(read(video, 1), area) .* uint8(xy));

    imshow(img2, 'InitialMagnification', length(img0)/length(img2)*100)
    title('Select approximately where the waterline intersects the structure')
    [x_s, ~] = ginput(1);
    close

    %isolate the structure outlined
    impact_area = edge(rgb2gray(img1.*uint8(~xy))); %area of the structure/removed area
    behind_area = edge((img2.*uint8(xy))); %dynamic area of impact
    impact_areas = impact_area;


    %perfrom a 'blur' of the impact area
    for i = -2:2
        for j = -2:2
            impact_hor = [zeros(i, x_img) ; impact_area(1 - min([0 i]) :end - max([0 i]), :) ; zeros(-i, x_img)];
            impact_areas = impact_areas + [zeros(y_img, j) impact_hor(:, 1 - min([0 j]) :end - max([0 j])) zeros(y_img, -j)];
        end
    end

    outline_thin = impact_areas.*behind_area; %the boundary of the impact zone
    outline_thick = zeros(y_img, x_img);

    %create a thicker outline when removing the structure from the
    %horizontal edges --> COMPLETELY removes it
    for i = -2:2
        for j = -2:2
            outline_hor = [zeros(i, x_img) ; outline_thin(1 - min([0 i]) :end - max([0 i]), :) ; zeros(-i, x_img)];
            outline_thick = outline_thick + [zeros(y_img, j) outline_hor(:, 1 - min([0 j]) :end - max([0 j])) zeros(y_img, -j)];
        end
    end

end
