function [pos, mov] = StationaryObject(video, outline_thick, area, xy)

    %{
    This function  tracks the intersect of water on a stationary object. 

    The main difference between this and MovingObject is that this
    function evaluates the vertical edge only once (the first frame) while
    MovingObject constantly re-evaulates the vertical edge

    Inputs: video, the video to be processed

            outline_thick, the thickened outline of the structure being
            impacted

            area, the original area of interest for processing

            xy, the area that is behind the structure and is not used in
            processing

    Output: pos, the positions in video where the intersect of water and 
            struture is

            mov, generated video which tracks image overlayed with the 
            detected intersect

            mov2, generated video which tracks the detected edges and
            intersect --> commented out ATM to increase script speed
    %}

    fprintf('\nStarting %s\n', video.name)

    %load constants and variables
    NumberOfFrames = video.NumberOfFrames;
    time = zeros(1, NumberOfFrames);
    ver_need = 1;
    pos = [];
    [y_img, x_img] = size(xy);

    for t = 1:NumberOfFrames
        
        tic
        
        %create a function that adjusts the image BETTER!!!
        img_raw = imcrop(read(video, t), area);
        img = imadjust(rgb2gray(img_raw .* uint8(xy)), [0; 0.5], [0; 1]);
        
        %calculate the vertical edges just once
        if t == 1 || ver_need
            ver = bwareaopen(edge(img, 'vertical'),30) + outline_thick;
        end 
        
        %get the horizontal edge
        hor = bwareaopen((edge(img,'horizontal') .* ~outline_thick), 20);

        int_y = [];
        int_x= [];
        ver_s = ver;
        hor_s = hor;
        k = 1;

        %find the intersect between the horizontal and vertical edges. If
        %an intersect isn't found increase the search up to five more pixels away
        while isempty([int_y, int_x]) && k < 3

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

        %if an intersect is detected, find the highest intersect
        if ~isempty(int_y)

            %find the index of the highest intercept
            [~, I] = min(int_y);

            %store the co-ordinate of the highest point
            store = [int_x(I) int_y(I)];
            
            ver_need = 0;
            
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

        %print the time remaining every 200 frames
        if t/200 == round(t/200) 
            fprintf('%.0f seconds remaining\n', (NumberOfFrames - t)*avg)
        end
    end
return
end
