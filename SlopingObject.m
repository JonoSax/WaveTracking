function[pos, mov] = SlopingObject(video, outline_thick, area, xy, x_s)

    %{
    This function tracks the intersect of water on an object which is sloping.

    This function is needed when the slope of the structure is less than 45º.
    This is because the edge detection funciton is, below structure of 45º,
    unable to differentiate between vertical (ie run up structure) and 
    horizontal (ie the water) edges.

    Inputs: video, the video to be processed

            outline_thick, the thickened outline of the structure being
            impacted

            area, the original area of interest for processing

            xy, the area that is behind the structure and is not used in
            processing

            x_s, the user approximated point of the initial water intersect
            with the object

    Output: pos, the positions in the video where the intersect of water and
            struture is

            mov, generated video which tracks image overlayed with the
            detected intersect

            mov2, generated video which tracks the detected edges and
            intersect --> commented out ATM to increase script speed
    %}

    fprintf('\nStarting %s\n', video.name)

    %ensure that the user approximated initial intersect is an integer
    x_s0 = round(x_s, 0);

    %load constants and variables
    NumberOfFrames = video.NumberOfFrames;
    time = zeros(1, NumberOfFrames);
    pos = [];
    [y_img, x_img] = size(xy);

    %get the edge of just the blurred slope
    img_orig = imadjust(rgb2gray(imcrop(read(video, 1), area).* uint8(xy)), [0; 0.5], [0; 1]);
    slope_area = bwareaopen((edge(img_orig) .* outline_thick), 50);
    slope_area(:, 1:x_s0) = 0; %assuming that the wave is travelling to the right
    slope_areas = slope_area;
    for i = -2:2 %vertical blur
        for j = -2:2 %horizontal blur
            slope_hor = [zeros(i, x_img) ; slope_area(1 - min([0 i]) :end - max([0 i]), :) ; zeros(-i, x_img)];
            slope_areas = slope_areas + [zeros(y_img, j) slope_hor(:, 1 - min([0 j]) :end - max([0 j])) zeros(y_img, -j)];
        end
    end
    
    slope_areas = logical(slope_areas); %ensure matrix is logical
    
    for t = 1:NumberOfFrames

        tic

        %create a function that adjusts the image BETTER!!!
        img_raw = imcrop(read(video, t), area);
        img = imadjust(rgb2gray(img_raw .* uint8(xy)), [0; 0.5], [0; 1]);

        %get the edges of the image minus the detected slope, ensure the 
        %matrix is logical
        water_area = bwareaopen(edge(img)-slope_areas >= 1, 50);
        
        %with the isloated wave, blur it
        water_areas = water_area;
        for i = -2:2 %vertical blur
            for j = -2:2 %horizontal blur
                slope_hor = [zeros(i, x_img) ; water_area(1 - min([0 i]) :end - max([0 i]), :) ; zeros(-i, x_img)];
                water_areas = water_areas + [zeros(y_img, j) slope_hor(:, 1 - min([0 j]) :end - max([0 j])) zeros(y_img, -j)];
            end
        end
              
        %set up variables for finding intersect
        int_y = [];
        int_x= [];
        ver = slope_areas >= 1; %convert to binary matrix
        ver_s = ver;
        hor = water_areas >= 1; %convert to binary matrix 
        hor_s = hor;
        k = 1;

        %find the intersect between the horizontal and vertical edges. If
        %an intersect isn't found increase the search up to five more pixels away
        while isempty([int_y, int_x]) && k < 5

            %imshow(ver_s.*hor_s)
            %find the intercepts between the detected horizontal and
            %vertical edges
            [int_y, int_x] = find(ver_s.*hor_s > 0);
            if isempty(int_y)
                for i = -k:k
                    for j = -k:k

                        %+i causes a downward shift
                        %vertical shift of edges
                        ver_shift = [zeros(i, x_img) ; ver(1 - min([0 i]) :end - max([0 i]), :) ; zeros(-i, x_img)];
                        hor_shift = [zeros(i, x_img) ; hor(1 - min([0 i]) :end - max([0 i]), :) ; zeros(-i, x_img)];

                        %+j causes a rightward shift
                        %horizontal shift of edges
                        ver_s = ver_s + [zeros(y_img, j) ver_shift(:, 1 - min([0 j]) :end - max([0 j])) zeros(y_img, -j)];
                        hor_s = hor_s + [zeros(y_img, j) hor_shift(:, 1 - min([0 j]) :end - max([0 j])) zeros(y_img, -j)];
                   end
                end
            end

            %iterate through increase the area of searching
            k = k + 1;
        end
        
        %find the height of the right most point --> this is the intercept
        %of the water on the slope
        if ~isempty(int_y)
            
            store = [max(int_x) int_y(find(int_x == max(int_x), 1))];

        else %if no intersect is found, set as NaN

            store = [NaN NaN];

        end
        
        %store the intersect found
        pos = [pos; store]; %#ok<AGROW>

        %create movie of the edges detected, blue is horizontal red is
        %vertical and the red dot is the detected intersect
        %______mov_2______
        %img_edge = im2uint8(255 - cat(3, 255*hor_s, 255*ver_s, 255*ver_s));
        
        try
            mov(t) = im2frame((insertShape(img_raw, 'Filledcircle', [store(1) store(2) 5], 'Color', 'red')));
            %mov2(t) = im2frame((insertShape(img_edge, 'Filledcircle', [store(1) store(2) 5], 'Color', 'red')));
        catch %if not intersect detected
            mov(t) = im2frame(img_raw);
            %mov2(t) = im2frame(img_edge);
        end

        time(t) = toc;

        %calculate the average time of all the frames so far
        avg = median(time(1:t));

        %print the approx time remaining every 200 frames
        if t/200 == round(t/200)
            fprintf('%.0f seconds remaining\n', (NumberOfFrames - t)*avg)
        end
    end
return
end