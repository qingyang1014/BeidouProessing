clc;
fprintf('start processing.\n');
tic;  %tic1
t1 = clock;
disp('***********************');
tt1 = cputime;
for i=1:3
    tic;  %tic2
    t2 = clock;
    pause(3*rand);
    disp(['the toc time: ',num2str(i),' time:',num2str(toc)]);
    disp(['etime time:',num2str(i),' time:',num2str(etime(clock,t2))]);
    disp('========================');
end
disp(['total etime is:',num2str(etime(clock,t1))]);
disp(['cputime results:',num2str(cputime-tt1)]);
    