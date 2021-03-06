close all
clear all

addpath('C:\Users\cryga\Documents\GitHub\HomeworkNS\Datasets');
y = 5;
switch y
    case 1
        G = importdata('wiki-Vote.txt', '\t', 4);
        N = max(max(G.data));
        A = sparse(G.data(:,2),G.data(:,1),ones(size(G.data,1),1),N,N);
        W = A; %Save adjacency matrix for later work on communities
        Au = 1*(A+A'>0); % undirected network
        clear G;
        if (isequal(A,Au))
            directed = 0;
        else
            directed = 1;
        end
    case 2
        G = importdata('bioCel.txt');
        N = max(max(G));
        A = sparse(G(:,2),G(:,1),ones(size(G,1),1),N,N);
        W = A;
        Au = 1*(A+A'>0); % undirected network
        clear G;
        if (isequal(A,Au))
            directed = 0;
        else
            directed = 1;
        end
    case 3
        G = importdata('ca_sandi_auths.txt');
        N = max(max(G));
        A = sparse(G(:,2),G(:,1),ones(size(G,1),1),N,N);
        W = A;
        Au = 1*(A+A'>0); % undirected network
        clear G;
        if (isequal(A,Au))
            directed = 0;
        else
            directed = 1;
        end
    case 4
        G = importdata('collaboration.edgelist.txt', '\t', 1);
        G.data = G.data + 1;
        N = max(max(G.data));
        A = sparse(G.data(:,2),G.data(:,1),ones(size(G.data,1),1),N,N);
        A = 1*(A+A'>0); % build undirected network
        clear G;
        if (isequal(A,Au))
            directed = 0;
        else
            directed = 1;
        end
    case 5
        A = importdata('occupyWs.txt');
        N = max(max(A));
        A = sparse(A(:,2),A(:,1),ones(size(A,1),1),N,N);
        A = 1*(A+A'>0); % build undirected network
        Au = 1*(A+A'>0); % undirected network
        clear G;
        if (isequal(A,Au))
            directed = 0;
        else
            directed = 1;
        end
end

% Equivalent undirected network, if it is the case
if directed
    pos = find(sum(Au)~=0);
    Au = Au(pos,pos);
    Au = Au - diag(diag(Au)); % clear diagonal
    A_red = A(pos,pos);
    
    if y == 1
        % Dead ends removal
        exit = false;
        while (~exit)
            pos = find(sum(A_red)~=0);
            A_red = A_red(pos,pos);
            Au = Au(pos,pos);
            N_red = size(A_red,1);
            exit = isempty(find(sum(A_red)==0, 1));
        end
    end
else
    pos = find(sum(A)~=0);
    A_red = A(pos,pos);
    Au = A_red;
end

% Network size
N = size(Au,1);
N_red = N;

%% Spectral domain info
% Spectral domain info
d = full(sum(Au)); % the degree vector
myd = d;
deg_sum = sum(d); % degrees sum
Di = spdiags(1./sqrt(d'),0,N,N); % diagonal degrees square-rooted
d = ones(N_red,1)./sqrt(d);
D = spdiags(d,0,N_red,N_red); % degree diagonal matrix
L = spdiags(ones(N_red,1),0,N_red,N_red) - D*Au*D; % the normalized Laplacian matrix
M = Au*Di*Di; % normalized adjacency matrix

%% %%%%%%%%%%%%%%%%%%% Link prediction schemes %%%%%%%%%%%%%%%%%%%%%

% Links removal - Randomly remove some links to create a temporal variation
% in the network

% Percentage of removed links
rm = ceil(0.2*deg_sum);
Au_bf = Au;

removal_type = 3;
switch removal_type
    case 1
        % Higher degree nodes
        [myd, pos] = sort(myd,'descend');
        tot = 0;
        i = 1;
        while i < length(myd)
            if tot < rm
                tot = tot + sum(myd(i));
                i = i + 1;
            else
                break;
            end
        end
        Au_bf(pos(1:i),:) = 0;
    case 2
        i = 0;
        while i < rm
            row = randi(size(Au,1));
            pos = find(Au(row,:));
            if pos
                Au_bf(row,pos(randi(length(pos)))) = 0;
                i = i + 1;
            end
        end
    case 3
        % Lower degree nodes
        [myd, pos] = sort(myd);
        tot = 0;
        i = 1;
        while i < length(myd)
            if tot < rm
                tot = tot + sum(myd(i));
                i = i + 1;
            else
                break;
            end
        end
        Au_bf(pos(1:i),:) = 0;
end

%%%%%%%%% Similarity estimation with different techniques %%%%%%%%%

% Common neighbour technique
S_cn = Au_bf*Au_bf;

% Adamic Adar and Resource alloction techniques
for i = 1:N_red
    for j = 1:N_red
        cn(j,:) = Au_bf(i,:).*Au_bf(j,:);
        k = find(cn(j,:)); %common neighbours to both i and j
        N_kaa = 0;
        N_kra = 0;
        for r = k
            n_k = find(Au_bf(r,:)); %neighbours of the common neighbours
            % AA technique
            if length(n_k) > 1
                N_kaa = N_kaa + (1/log(length(n_k)));
            end
            % RA technique
            if ~isempty(r)
                N_kra = N_kra + (1/length(n_k)); % The sum goes to inf becaus there are very many common neighbours with a low degree
            end
        end
        S_aa(i,j) = N_kaa;
        S_ra(i,j) = N_kra;
    end
    y =3;
end

%%%%%% Path based techniques

damp = 0.75; % Damping factor

% Katz technique
diam = 5;
l = 1:diam; % Take paths at most long "diam"
S_ka = damp*Au_bf;
for i = 2:diam
    S_ka = S_ka + (damp^i)*(Au_bf^i);
end

% Local Path (LP) technique

S_lp = Au_bf^2 + damp*(Au_bf^3);

%%%%%%%%% Precision estimation techniques %%%%%%%%%

%%% Precision method

top_links = rm; % Top links based on S
P = Au_bf(1:30,1:30); %Probe set of edges

% Similarity measures ordered
sim = 5;
switch sim
    case 1
        tmp = S_ra;
    case 2
        tmp = S_aa;
    case 3
        tmp = S_cn;
    case 4
        tmp = S_lp;
    case 5
        tmp = S_ka;
end

i = 1;
idx = zeros(rm,2);
while i <= rm
    [myMax, pos1] = max(tmp);
    [Max,pos2] = max(myMax);
    col(i) = pos2;
    row(i) = pos1(col(i));
    idx(i,1) = row(i);
    idx(i,2) = col(i);
    tmp(idx(i,1),idx(i,2)) = 0;
    i = i + 1;
end
idx_top = idx;
percentage_top = sum(row < 31)/deg_sum;

switch sim
    case 1
        tmp = S_ra;
        str = '_ra';
    case 2
        tmp = S_aa;
        str = '_aa';
    case 3
        tmp = S_cn;
        str = '_cn';
    case 4
        tmp = S_lp;
        str = '_lp';
    case 5
        tmp = S_ka;
        str = '_ka';
end

i = 1;
while i <= rm
    [myMin, pos1] = min(tmp);
    [Min,pos2] = min(myMin);
    col(i) = pos2;
    row(i) = pos1(col(i));
    idx(i,1) = row(i);
    idx(i,2) = col(i);
    tmp(idx(i,1),idx(i,2)) = 0;
    i = i + 1;
end
idx_bottom = idx;
percentage_bottom = sum(row < 31)/deg_sum;

%%%%%% Confusion matrix generation %%%%%%
% TP: check if in idx positions in actual Au there are links
check = zeros(length(idx_top),1);
for i = 1:length(idx_top)
    check(i) = full(Au(idx_top(i,1),idx_top(i,2)) > 0);
end
tp = sum(check); % true positive edge predictions

% FP: check if in idx positions in actual Au there are no links
for i = 1:length(idx_top)
    check(i) = full(Au(idx_top(i,1),idx_top(i,2)) == 0);
end
fp = sum(check); % false positive edge prediction

% FN: check if in idx positions in actual Au there are actually links
for i = 1:length(idx_bottom)
    check(i) = full(Au(idx_bottom(i,1),idx_bottom(i,2)) > 0);
end
fn = sum(check);

% TN: check if in idx positions in actual Au there are actually links
for i = 1:length(idx_bottom)
    check(i) = full(Au(idx_bottom(i,1),idx_bottom(i,2)) == 0);
end
tn = sum(check);

% Precision estimation
eval(['Prec', num2str(str), ' = tp./(tp + fp)']);
% Recall estimation - TPR
eval(['Rec', num2str(str), ' = tp./(tp + fn)']);
% Specificity
eval(['Spec', num2str(str), ' = tn./(tn + fp)']);
% F-measure
eval(['Fm', num2str(str), ' = (2.*Rec', num2str(str), '.*Prec', num2str(str), ')./(Rec', num2str(str), '+Prec', num2str(str), ')']);
%%% AUC method

% Creation of the Probe set and the Inactive set 
P = triu(Au_bf(1:30,1:30)); %Probe set of edges
In = triu(abs(Au_bf - ones(size(Au_bf,1),size(Au_bf,2)))); %Set of inactive edges

% AUC implementation
eval(['auc', num2str(str), '= 0;']);

for i = 1:size(In,1) % Rows of In
    for j = 1:size(In,2) % Columns of In
        for p = 1:size(P,1) % Rows of P
            for k = 1:size(P,2) % Columns of P
                if (In(i,j) == 1) && (P(p,k) == 1)
                    eval(['auc',num2str(str),' = auc',num2str(str),'+(S',num2str(str),'(p,k)>S',num2str(str),'(i,j));']);
                end
            end
        end
    end
end

mod_In = sum(sum(In));
mod_P = sum(sum(P));
if mod_P == 0
    mod_P = 1;
end

eval(['auc', num2str(str), '= auc', num2str(str), '/(mod_In*mod_P);']);

% Save results
switch removal_type
    case 1
        filename = ['LPresults_higherDegree_', num2str(str)];
    case 2
        filename = ['LPresults_rand_',num2str(str)];
    case 3
        filename = ['LPresults_lowerDegree_', num2str(str)];
end
save(filename,['Prec',num2str(str)],['Spec',num2str(str)],['Rec',num2str(str)],['Fm',num2str(str)],['auc',num2str(str)]);

%% %%%%%%%%%%%%%%%%%%%%% SPECTRAL CLUSTERING %%%%%%%%%%%%%%%%%%%%%%%

if N < 2e3
    [eigv, lambdas] = eigs(L); %extracting eigenvalues and eigenvectors
    
    figure('Name','Eigenvalues of the Laplacian')
    plot(diag(lambdas),'o');
    grid
    title('Eigenvalues of the normalized Laplacian')
else
    [eigv, lambdas] = eigs(L,3);
end

% Normalize the eigenvectors
Neigv = D*eigv;
% Find the Fiedler vector x_N-1 and normalize it
fv1 = Neigv(:,2)/norm(Neigv(:,2));
% Extract the following vector
fv2 = Neigv(:,3)/norm(Neigv(:,3));

% Identifying communities wrt to fv1
comm1 = find(fv1>0);
comm2 = find(fv1<0);

%% Reordering the nodes wrt fiedler's vector

% reorder the adjacency matrix
[B,pos] = sort(fv1);
Wu_ord = Au(pos,pos);

% Finding the conductance measure
a = sum(triu(Wu_ord)); % the degree of the columns
b = sum(tril(Wu_ord)); % the degree of the rows
d = a + b; % the total degree
newD = sum(d);

% association update
assoc = cumsum(d);
den = min(assoc,newD - assoc);

% cut update
cut = cumsum(b - a);

% the conductance
cond = cut./den;
cond = cond(1:end-1);

% plotting the conductance measure
figure('Name','Conductance measure')
plot(cond,'g--')
grid
ylabel('conductance')
title('sweep choice')
ylabel('Cond');

saveas(gcf,'Conductance.png');

% minimum conductance
disp(['the minimum conductance is: ', num2str(min(cond))]);

% The cheeger's bound
cb = sqrt(2*lambdas(2,2));

disp(['The cheeger''s bound is : ', num2str(cb)]);
if (min(cond) < cb)
    disp('Congrats, you found a good community!');
else
    disp('Are you sure it is the right way?');
end

%% Network partitioning

% show network with partition
[mincond,mpos] = min(cond);
threshold = mean(B(mpos:mpos+1));
disp(['Community 1 size: ', num2str(mpos)]);
disp(['Community 2 size: ', num2str(N - mpos)]);

figure('Name','Network communities')
plot(fv1,fv2,'.')
grid
hold on
plot(threshold*[1,1],ylim,'r-')
hold off
title('communities')

saveas(gcf,'Communities.png');

% show network with partition and links
if newD < 1e4 % only if edges are not too many!!!
    figure('Name','Communities connected')
    plot(fv1,fv2,'.')
    grid
    [I,J,~] = find(Au);
    hold on
    plot([fv1(I),fv1(J)]',[fv2(I),fv2(J)]')
    plot(threshold*[1,1],ylim,'k-')
    hold off
    title('communities (with links)')
    
    saveas(gcf,'NetworkCommunities.png');
end

% % % % save network of largest community 
% % % if (mpos >= N-mpos)
% % %     A_red = A_red(pos(1:mpos),pos(1:mpos));
% % % else
% % %     A_red = A_red(pos(mpos+1:end),pos(mpos+1:end));
% % % end

%% PageRank-nibble approach

% Again, the degree vector
d = full(sum(Au));

if mpos < N-mpos  % select seed node from the smaller group
    i = pos(1); % we select the more relevant from the perspective of the spectral approach
else
    i = pos(end);
end
q = zeros(N,1);
q(i) = 1; % teleport vector
c = 0.85;
Idt = spdiags(ones(N,1),0,N,N); % identity matrix
r = (Idt-c*M)\((1-c)*q); % ranking vector
ep = 1e-3; % precision

% run PageRank-nibble
u = zeros(N,1); % starting point
v = q; % starting point
th = full(ep*d/deg_sum)'; % thresholds
count = 0; % exit counter
complexity = 0; % complexity value (# of operations)
ii = i; % starting index used for Push operation
while (count<N)
    if v(ii)>th(ii) % push if above threshold
        tmp = v(ii);
        u(ii) = u(ii)+(1-c)*tmp;
        v(ii) = 0;
        v = v + c*M(:,ii)*tmp;    
        complexity = complexity + d(ii); % update complexity
        count = 0; % reset the exit counter
    else % go to next entry if below threshold
        count = count + 1; % increase the exit counter
        ii = mod(ii,N)+1; % update the index used for Push
    end
end

% sweep wrt the ordering identified by v1
% reorder the adjacency matrix
[u1s,pos2] = sort(u,'descend');
Nmax = find(u1s>0,1,'last'); % discard nodes with 0 values (never used in Push)
Au1 = Au(pos2,pos2(1:Nmax));
% evaluate the conductance measure
a = sum(triu(Au1));
b = sum(tril(Au1));
assoc = cumsum(a+b);
assoc = min(assoc,deg_sum-assoc);
cut = cumsum(b-a);
conduct = cut./assoc;
conduct = conduct(1:Nmax-1); 
% identify the minimum -> threshold
[~,mpos2] = min(conduct);
threshold2 = mean(u1s(mpos2:mpos2+1));
disp('PageRank-nibble approach')
disp(['   complexity/deg_sum: ' num2str((complexity/deg_sum))])
disp(['   epsilon: ' num2str(ep)])
disp(['   prec: ' num2str(norm(r-u,1))])
disp(['   Minimum conductance: ' num2str(conduct(mpos2))])
disp(['   # of links: ' num2str(deg_sum/2)])
disp(['   Cut value: ' num2str(cut(mpos2))])
disp(['   Assoc value: ' num2str(assoc(mpos2))])
disp(['   Community size #1: ' num2str(mpos2)])
disp(['   Community size #2: ' num2str(N-mpos2)])

% show sweep choice
figure('Name','Conductance with PageRank-Nibble')
plot(conduct,'g--')
grid
ylabel('conductance')
title('sweep choice')

filename = 'condNibble.png';
saveas(gcf,filename);

% show network with partition
figure('Name','Network patitions with PageRank-Nibble')
plot(u,fv1,'k.')
hold on
% plot(u(pos2(1:mpos2)),v1(pos2(1:mpos2)),'go')
plot(threshold2*[1,1],ylim,'g-')
plot(xlim,threshold*[1,1],'r-')
hold off
grid
ylabel('Fiedler''s eigenvector value')
xlabel('PageRank value')
title('communities')

filename = 'CommunitiesNibble.png';
saveas(gcf,filename);
%% %%%%%%%%%%%%%%%%%%%%%%%% PageRank algorithm %%%%%%%%%%%%%%%%%%%%%

if directed % find the largest connected component for the directed graph
    e1 = [1;zeros(N_red-1,1)];
    exit = false;
    while(~exit)
        e1_old = e1;
        e1 = 1*(Au*e1>0);
        exit = (sum(e1-e1_old)==0);
    end
    idx = find(e1);
    A_red = A_red(idx,idx);
    N_red = size(A_red,1);
end

%% PageRank equation evaluation 

c = 0.85; %damping factor
q = ones(N_red,1)/N_red; %teleportation vector
d_out = (A_red)'*ones(size(A_red,1),1); %output degree vector
d_out_2 = sum(A_red,2);
diff = d_out - d_out_2;
d_out = sparse(ones(length(d_out),1)./d_out);
d_out_2 = sparse(ones(length(d_out_2),1)./d_out_2);
AdjM = A_red*sparse(diag(d_out)); %Weighted adjacency matrix
M_11 = c*AdjM;
M_12 = (1-c)*q;

% Through linear system solution
tic
pr_ls = (sparse(eye(size(AdjM,1))) - M_11)\M_12;
pr_ls = pr_ls/sum(pr_ls);
toc

% Through power iteration
t = 10; % number of iterations
tic
pr = ones(N_red,1)/N_red; % initial guess on p_0(i)
s = zeros(t,1);
for i = 1:t
    pr_old = pr;
    % iterative step
    pr = M_11*pr + M_12;
    pr = pr/sum(pr);
    s(i) = norm(pr - pr_ls)/sqrt(N_red);
end
toc
distance = s;

%%%%%%%%%%%% Checking for convergence %%%%%%%%%%%%%

% Extract eigenvalues
disp('6 biggest eigenvalues extraction')
tic
% dbstop if naninf
[V, lambdas Flag]= eigs(AdjM);
toc
if Flag
    disp('Eigenvalues not found, eigs does not converge!')
end

lambda_2 = lambdas(2,2); %take the second eigenvalue, since the first one is 1 and stands for the connected component

thr = (c*abs(lambda_2)).^(1:t);
convergence = (distance' <= thr); %Checking if there is convergence in the solution

figure('Name','Convergence of the power iteration method for PageRank equation')
set(0,'defaultTextInterpreter','latex') % to use LaTeX format
semilogy((1:t),distance)
grid
xlabel('k [iteration \#]')
ylabel('$\|r_k - r_\infty\|$')
title('PageRank convergence')

lambdas = eigs(AdjM,size(AdjM,1));

figure('Name','Eigenvalues representation')
plot(real(lambdas(2:end)),imag(lambdas(2:end)),'o')
hold on
viscircles([0 0],abs(lambdas(1)),'Color','g');
hold off
grid

%% TrustRank equation evaluation

c = 0.85; %damping factor
q = ones(N_red,1)/N_red; %teleportation vector
d_in = (A_red)*ones(size(A_red,1),1); %input degree vector
d_in = sparse(ones(length(d_in),1)./d_in);
UdjM = A_red'*sparse(diag(d_in)); %Weighted inverse adjacency matrix
iter = 20; % Number of power iterations
L = ceil(N_red*(3/7)); %Number of oracle invocations proportioned to the value in the paper
M_b = 20; % Number of trustRank iterations

% Selecting seeds
tic
s = ones(N_red,1); % seeds vector initialization

for i = 1:iter
    s = c*UdjM*s + (1-c)*q;
end

% First I have to write down the sigma function that returns an array of
% indeces corresponding to the nodes in the network ordered in descending
% order wrt their seed score s
temp = s;
s = sort(s,'descend');
sigma = zeros(length(s),1);
for i = 1:length(s) - 1
    sigma(i) = find(s(i) == temp,1);
    if s(i) == s(i+1)
        temp(sigma(i)) = 0;
    end
end
sigma(end) = find(s(end) == temp,1);

%Oracle function. We need to estimate the probability of one seed of being
%"a good page". To do this we suppose that seeds belonging to one community
%are the good ones while the others are the bad ones. For this case we take
%the communities found with the spectral clustreing approach of the upper
%section

O = zeros(N_red,1);
for i = 1:N_red
    if (ismember(i,comm1)) % If the node belongs to the first (good) community
        O(i) = 1;
    else %If it belongs to the second community
        O(i) = 0;
    end
end

% Whole TrustRank algorithm
q = zeros(N_red,1);
distance = zeros(1,M_b);
for i = 1:L
    if O(sigma(i)) == 1 % The entries of the static score teleport vector
                        % belog to a good community then are set to 1
        q(sigma(i)) = 1;
    end
end
q = q/sum(q); % normalization of the vector so that the entries sum up to 1
trust = q; % initialization of the trust score
for j = 1:M_b % Power iteration step
    trust = c*AdjM*trust + (1-c)*q;
    distance(j) = norm(trust)/sqrt(N_red);
end
toc
filename = 'TrustVal.mat';
save(filename,'trust','distance');

% Check if the trust score corresponds to the intended community
thr = mean(trust);
trust_1 = 0;
trust_2 = 0;
for i = 1:N_red
    if ismember(i,comm1) %good community
        trust_1 = [trust_1, trust(i)];
    else
        trust_2 = [trust_2, trust(i)];
    end
end
trust_1 = trust_1(2:end);
trust_2 = trust_2(2:end);
check_1 = (trust_1 > thr);
check_2 = (trust_2 < thr);

% Percentage of pages considered trustworthy in the good community
perc_trust = sum(check_1)/length(trust_1);
% Percentage of pages considered untrustworthy in the bad community
perc_distrust = sum(check_2)/length(trust_2);

figure('Name','Convergence of the power iteration method for TrustRank equation')
set(0,'defaultTextInterpreter','latex') % to use LaTeX format
semilogy((1:M_b),distance)
grid
xlabel('k [iteration \#]')
ylabel('$\|r_k - r_\infty\|$')
title('TrustRank convergence')

filename = 'TrustRank_Convergence.png';
saveas(gcf,filename);

%% HITS equation evaluation - authorities/hubs scores

AdjM = sparse(A_red*A_red');

% Through linear system solution
tic
[hits_ls_vect, hits_ls] = eigs(AdjM,2);
toc
pr_dir_aut = -hits_ls_vect(:,1)/norm(hits_ls_vect(:,1)); % Extract the most importand dimension and project the values wrt to that (SVD)

% Through power iteration
tic
hits = ones(N_red,1)/N_red; % initial guess
s = zeros(t,1);
for i = 1:t
    temp = hits;
    hits = AdjM*hits; % iterative step
    hits = hits/norm(hits); % normalization step
    s(i) = norm(hits - temp)/sqrt(N_red);
end
toc

thr_hubs = (abs(hits_ls(2,2)/hits_ls(1,1))).^(1:t);
norm_thr = thr_hubs/thr_hubs(end); % normalized threshold
convergence_hits = (s <= thr); %Checking if there is convergence in the solution
n_iterForConv = find((s  - s(end)*norm_thr) < 1e-2,1);

figure('Name','Convergence of the power iteration method for Hits authorities/hubs')
set(0,'defaultTextInterpreter','latex') % to use LaTeX format
semilogy((1:t),s)
hold on
semilogy((1:t),s(end)*norm_thr); % Minimum value correspondence
hold off
grid
xlabel('k [iteration \#]')
ylabel('$\|hits_k - hits_\infty\|$')
title('Hits convergence')

disp(['The power iteration method converges after ', num2str(n_iterForConv), ' iterations']);

filename = 'Convergence_hits.png';
saveas(gcf, filename)

%% %%%%%%%%%%% Comparing PageRank and Hits %%%%%%%%%%%%%%

figure('Name','Comparison between PageRank and Hits authorities scores')
plot(pr_dir_aut/sum(pr_dir_aut),pr_ls/sum(pr_ls),'o')
grid
title('PageRank vs HITS ')

figure('Name','Comparison between PageRank and hits authorities scores')
set(0,'defaultTextInterpreter','latex') % to use LaTeX format
plot(1:N_red,pr_ls/sum(pr_ls))
grid
hold on
plot(1:N_red,-pr_dir_aut/sum(pr_dir_aut))
hold off
legend('PageRank','Hits')
title('PageRank vs HITS ')

filename = 'PRcompHits.png';
saveas(gcf,filename);
