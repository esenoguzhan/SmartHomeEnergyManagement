clc
clear

season = input("+ type \n- 1 for summer \n- 2 for winter \nPlease choose the season: ");
%% transferring excel tables to matlab

switch season
    case 1
%Summer Season Codes
loads = xlsread('loads_summer', 'B2:AC18'); 
shifted_loads = loads;
irradiance_values = xlsread('irradience_summer','B3:AC3');
[~,load_titles] = xlsread('loads_summer', 'A3:A18');
%
    case 2
%Winter Season Codes
loads = xlsread('loads_winter', 'B2:AC19'); 
shifted_loads = loads;
irradiance_values = xlsread('irradience_winter','B3:AC13');
[~,load_titles] = xlsread('loads_winter', 'A3:A19');
%
end
    
hours = 0:27;
constant_load_value = [];

%% Variables

threshold = 6250;
pv_panel_count = 12;
max_output_pv_panels = 330;

%% Determination of peak hours

initial_peak_hour = 17; 
peak_time_duration = 5; 

%% Calculations of PV panel output powers  

pv_panel_output = irradiance_values*max_output_pv_panels/1000;
total_pv_panel_power = pv_panel_output*pv_panel_count;

%% Arranging priorities

priority_level = {};

switch season
    case 1
        % Priority codes for summer

       priority_level{1} = loads(1:3, :);     % Low level priority
       priority_level{2} = loads(4:10, :);    % Mean level priority
       priority_level{3} = loads(11:16, :);   % High level priority
        %
    case 2 
        % Priority codes for winter
        priority_level{1} = loads(1:4, :);      % Low level priority
        priority_level{2} = loads(5:11, :);     % Mean level priority
        priority_level{3} = loads(12:17, :);    % High level priority
        %
end
%% Calculations of generated and consumed power

hourly_generated_power = total_pv_panel_power;
hourly_consumptions = sum(loads);
hourly_net = hourly_consumptions - hourly_generated_power ;

%% Drawing the graph b4 shifting

hourly_net_b4_shifting = hourly_net;
figure,
hold on
stairs(hours, hourly_consumptions, 'r', 'LineWidth',1.5);
stairs(hours, hourly_generated_power, 'g', 'LineWidth',1.5);
stairs(hours, hourly_net, 'b', 'LineWidth',1.5);
legend('Consumptions','Generated','Total','Location','north');
xlabel('hours')
ylabel('watt')
hold off
figure,
stairs(hours, hourly_net_b4_shifting, 'r','LineWidth',2);
hold off

%% shifting for peak hours

switch season
    case 1
for i = 1:size(load_titles)
 if (strcmp(load_titles(i), 'Air Conditioner') || strcmp(load_titles(i), 'Laptops')||strcmp(load_titles(i), 'Lighting') || strcmp(load_titles(i), 'Boiler') || strcmp(load_titles(i),'Wireless Modem') || strcmp(load_titles(i), 'Refrigerator'))
 constant_load_value = [constant_load_value, i];
 end
end
    case 2
for i = 1:size(load_titles)
 if (strcmp(load_titles(i), 'Heater') || strcmp(load_titles(i), 'Laptops')||strcmp(load_titles(i), 'Lighting') || strcmp(load_titles(i), 'Boiler') || strcmp(load_titles(i),'Wireless Modem') || strcmp(load_titles(i), 'Refrigerator'))
 constant_load_value = [constant_load_value, i];
 end
end
end

[high_index, ~] = size(priority_level{3});
[mean_index, ~] = size(priority_level{2});
index_offset = high_index + mean_index;

priority_index = 1;
t = initial_peak_hour + 1;
priority_check = priority_level{priority_index};
after_shifting_hourly = hourly_net;

while t <= initial_peak_hour + peak_time_duration + 1
 fprintf('Priority index: %s\n',num2str(priority_index));
 hourly_consumpiton = after_shifting_hourly(t);
 if(hourly_consumpiton > threshold)
 fprintf('\n*For hour:%s ,Consupmtion is higher then threshold!! (%s)',num2str(t-1), num2str(hourly_consumpiton));
 [max_consumption_in_priority, index_in_priority] = max(priority_check(:, t));
 fprintf('\nMax consumption in priority: %s\n',num2str(max_consumption_in_priority));
 if(max_consumption_in_priority > 0)
 index_shift = index_in_priority + index_offset;
 fprintf('Index shift: %s\n',num2str(index_shift));
 if(find(constant_load_value == index_shift))
 fprintf('Constant load index: %s shifting is unnecessary!!\n',num2str(index_shift));
 priority_check(index_in_priority, t) = 0;
 else
 fprintf('Shifting index: %s\n',num2str(index_shift));
 shifted_loads(index_shift, :) = [shifted_loads(index_shift, 1:t-1), 0, shifted_loads(index_shift, t:27)];
 priority_check(index_in_priority,:) = [priority_check(index_in_priority, 1:t-1), 0, priority_check(index_in_priority, t:27)];
 priority_shift = priority_level{priority_index};
 priority_level{priority_index}(index_in_priority,:) = [priority_shift(index_in_priority, 1:t-1), 0, priority_shift(index_in_priority, t:27)];
 
 %Calculating hourly-net state after shifting
 
 shifted_hourly_consumptions = sum(shifted_loads);
 after_shifting_hourly = shifted_hourly_consumptions - hourly_generated_power;
 fprintf('New consumption for hour: %s\n',num2str(after_shifting_hourly(t)));
 end
 
 else
 % Changing priority level
 if(priority_index < 3) 
 fprintf('Changing priority from: %s to: %s\n',num2str(priority_index), num2str(priority_index + 1));
 priority_index = priority_index + 1;
 priority_check = priority_level{priority_index};
 if(priority_index == 3)
 index_offset = 0;
 else
 [next_priority_index, ~] = size(priority_level{3});
 index_offset = next_priority_index;
 end
 else
 fprintf('There is no next priority \n');
 fprintf('Can not reduce comsumption \n');
 fprintf('Reduction: %s \n', num2str(hourly_net(t) - after_shifting_hourly(t)));
 t = t + 1;
 end
 end
 
 else
 
 fprintf('\nNo need shifting for hour: %s\n',num2str(t-1));
 fprintf('reduction: %s \n', num2str(hourly_net(t) - after_shifting_hourly(t)));
 t = t + 1;
 priority_index = 1;
 priority_check = priority_level{priority_index};
 index_offset = high_index + mean_index;
 end
end

%% Adding Battery to the System

battery_capacity = max(sum(loads))/2; %half	of	the	maximum	load of home 
battery_SoC = battery_capacity * 0.1;  %initial state of battery

battery_consumption = zeros (1,28);    

for i = 1 : 18                          
    if battery_SoC < (battery_capacity * 0.8)
    battery_SoC = battery_SoC + (battery_capacity * 0.2);
    fprintf("\n for hour:%d battery is charging\n",i)
    battery_consumption(i)= (battery_capacity * 0.2);
    else
        fprintf("\n for hour:%d battery SoC is higher then %%80\n",i)
    end
end

battery_supply =zeros(1,28); 

for i= 19 : 21 
    if battery_SoC > (battery_capacity * 0.3)
    fprintf("\n for hour:%d battery is discharging\n",i)
    battery_supply(i)=(battery_capacity * 0.3);
    battery_SoC = battery_SoC - (battery_capacity * 0.3);
    else
        fprintf("\n for hour:%d battery capacity is insufficient for supply,battery SoC lower then %%30\n",i)
    end
end

for i = 22 : 23
    if battery_SoC < (battery_capacity * 0.8)
        battery_SoC = battery_SoC + (battery_capacity * 0.2);
        fprintf("\n for hour:%d battery is charging\n",i)
        battery_consumption(i)= (battery_capacity * 0.2);
    else 
        fprintf("\n for hour:%d battery SoC is higher then %%80\n",i)
    end
end

%% Recalculate after adding battery

after_shifting_hourly = after_shifting_hourly + battery_consumption;
 
%% The sale of excessive panel power

outOfConsumption= zeros(1,28);
for t = 1:26
    if after_shifting_hourly(t) < 0
        outOfConsumption(t) = outOfConsumption(t) - after_shifting_hourly(t);
        after_shifting_hourly(1,t) = 0;
        hourly_net_b4_shifting(1,t) = 0;
    end
end
toGrid = sum(outOfConsumption);
          
%% Drawing graphs after shifting

stairs(hours, hourly_net_b4_shifting, 'r','LineWidth',2);
hold on
stairs(hours, after_shifting_hourly, 'b','LineWidth',1.5);
stairs(hours, battery_supply, 'g','LineWidth',1.5);
legend('Before Shifting','After Shifting', 'Battery Supply','Location','north');
xlabel('hours')
ylabel('watt')
hold off

%% Final calculation of consumption and classification by hours

shifted_day_consumption = sum(after_shifting_hourly(7:17));
shifted_peaktime_consumption = sum(after_shifting_hourly(18:21)) - sum(battery_supply);
shifted_nighttime_consumption = sum(after_shifting_hourly(22:23)) + sum(after_shifting_hourly(1:6));

%% Classifying consumption hours b4 shifting

day_consumption_b4shitfing = sum(hourly_net(7:17));
peak_consumption_b4shifting = sum(hourly_net(18:21));
night_consumption_b4shifting = sum(hourly_net(22:23)) + sum(hourly_net(1:6));

%% Hourly electric price

daytime_price = 0.400385;
peaktime_price = 0.680197;
nigth_price = 0.176620;
sell_price = 0.31;

%% Calculating total costs and savings

battery_saving = (sum(battery_supply)* peaktime_price) / 1000;
total_price_aftershifting = shifted_day_consumption * daytime_price + shifted_peaktime_consumption * peaktime_price + shifted_nighttime_consumption * nigth_price;
total_price_b4shifting = day_consumption_b4shitfing * daytime_price + peak_consumption_b4shifting * peaktime_price + night_consumption_b4shifting * nigth_price;
total_saving_afterselling = (toGrid*sell_price) / 1000;
fprintf('\n\n\n+ Total Price Before Shifting: %s liras \n',num2str(total_price_b4shifting / 1000));
fprintf('\n+ Total Price After Shifting: %s liras \n',num2str(total_price_aftershifting / 1000));
fprintf('\n+ Save: %s liras with shifting \n',num2str((total_price_b4shifting - total_price_aftershifting) / 1000));
fprintf('\n+ Save: %f liras with using battery on peak time \n',battery_saving);
fprintf('\n+ Save: %f liras with selling to grid \n',total_saving_afterselling);
total_saving = total_saving_afterselling + (total_price_b4shifting - total_price_aftershifting) / 1000 + battery_saving;
fprintf('\n+ Total savings: %f liras\n',total_saving);
fprintf('\n+ Last Bill Price: %f liras\n',total_price_b4shifting / 1000 - total_saving);
fprintf('\n+ We reached %f percent total profit! \n',((total_price_b4shifting / 1000)-(total_price_b4shifting / 1000 - total_saving))/(total_price_b4shifting / 1000) * 100);
