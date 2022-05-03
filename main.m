clear ; close all; clc
load('train.mat');
fprintf('\nTraining Linear SVM\n', '(this may take 1 to 2 minutes) ...\n')
p = 0.1;
md = train(X, y, p, @linearKernel);
o = presvm(md, X);
fprintf('Training Accuracy: %f\n', mean(double(o == y)) * 100);
load('test.mat');
fprintf('\n On a test set, the trained Linear SVM is evaluated. ...\n')
o = presvm(md, Xtest);
fprintf('Test Accuracy: %f\n', mean(double(o == ytest)) * 100);
filename = fopen('Dataset.txt');
tline = fgetl(filename);
while ischar(tline)
    tline = fgetl(filename);
% Read and predict
line = tline;
wi  = pe(line);
x = fe(wi);
o = presvm(md, x);
fprintf('\nProcessed %s\n\nSpam Classification: %d\n', filename, o, '(1 indicates spam, 0 indicates not spam)\n\n');
end
fclose(filename);

function [md] = train(X, Y, p, kernelFunction, tl, maxp)
if ~exist('tl', 'var') || isempty(tl)
    tl = 1e-3; end
if ~exist('maxp', 'var') || isempty(maxp)
    maxp = 5; end
q = size(X, 1);
n = size(X, 2);
Y(Y==0) = -1;
ap = zeros(q, 1);
b = 0;
E = zeros(q, 1);
pass = 0;
ea = 0;
A = 0;
I = 0;
if strcmp(func2str(kernelFunction), 'linearKernel')
    S = X*X';
elseif strfind(func2str(kernelFunction), 'gaussianKernel')
else S = zeros(q);
    for i = 1:q
        for j = i:q
             S(i,j) = kernelFunction(X(i,:)', X(j,:)');
             S(j,i) = S(i,j); end; end; end
fprintf('\nTraining ...');
dots = 12;
while pass < maxp            
    num_changed_alphas = 0;
    for i = 1:q
        E(i) = b + sum (ap.*Y.*S(:,i)) - Y(i);
        if ((Y(i)*E(i) < -tl && ap(i) < p) || (Y(i)*E(i) > tl && ap(i) > 0))
            j = ceil(q * rand());
            while j == i  j = ceil(q * rand());end
            E(j) = b + sum (ap.*Y.*S(:,j)) - Y(j); ap_i_old = ap(i);
            ap_j_old = ap(j);
            if (Y(i) == Y(j))  A = max(0, ap(j) + ap(i) - p);
                I = min(p, ap(j) + ap(i));
            else A = max(0, ap(j) - ap(i));
                I = min(p, p + ap(j) - ap(i)); end
            if (A == I) continue; end
            ea = 2 * S(i,j) - S(i,i) - S(j,j);
            if (ea >= 0) continue; end
            ap(j) = ap(j) - (Y(j) * (E(i) - E(j))) / ea;
            ap(j) = min (I, ap(j));
            ap(j) = max (A, ap(j));
            if (abs(ap(j) - ap_j_old) < tl)  ap(j) = ap_j_old; continue; end 
            ap(i) = ap(i) + Y(i)*Y(j)*(ap_j_old - ap(j)); 
            b01 = b - E(i) - Y(i) * (ap(i) - ap_i_old) *  S(i,j)' - Y(j) * (ap(j) - ap_j_old) *  S(i,j)';
            b02 = b - E(j) - Y(i) * (ap(i) - ap_i_old) *  S(i,j)' - Y(j) * (ap(j) - ap_j_old) *  S(j,j)'; 
            if (0 < ap(i) && ap(i) < p)
                b = b01;
            elseif (0 < ap(j) && ap(j) < p) b = b02;
            else b = (b01+b02)/2; end
            num_changed_alphas = num_changed_alphas + 1; end; end



    if (num_changed_alphas == 0)  pass = pass + 1;
    else  pass = 0; end
    fprintf('.');
    dots = dots + 1;
    if dots > 78
        dots = 0;
        fprintf('\n'); end
    if exist('OCTAVE_VERSION')
        fflush(stdout); end; end
fprintf(' Done! \n\n');
idx = ap > 0;
md.X= X(idx,:);
md.y= Y(idx);
md.kernelFunction = kernelFunction;
md.b= b;
md.ap= ap(idx);
md.w = ((ap.*Y)'*X)'; end

function pred = presvm(md, X)
if (size(X, 2) == 1)
    X = X'; end
q = size(X, 1);
o = zeros(q, 1);
pred = zeros(q, 1);
if strcmp(func2str(md.kernelFunction), 'linearKernel')
    o = X * md.w + md.b;
else
    for i = 1:q
        prediction = 0;
        for j = 1:size(md.X, 1)
            prediction = prediction + md.ap(j) * md.y(j) * md.kernelFunction(X(i,:)', md.X(j,:)'); end
        o(i) = prediction + md.b;end;end
pred(o >= 0) =  1;
pred(o <  0) =  0;end



function file_contents = readFile(filename)
fid = fopen(filename);
if fid
    file_contents = fscanf(fid, '%c', inf);
    fclose(fid);
else file_contents = '';
    fprintf('Unable to open %s\n', filename); end; end
function wi = pe(email_contents)
vocabList = getVocabList();
wi = [];
email_contents = lower(email_contents);
email_contents = regexprep(email_contents, '<[^<>]+>', ' ');
email_contents = regexprep(email_contents, '[0-9]+', 'number');
email_contents = regexprep(email_contents, '(http|https)://[^\s]*', 'httpaddr');
email_contents = regexprep(email_contents, '[^\s]+@[^\s]+', 'emailaddr');
email_contents = regexprep(email_contents, '[$]+', 'dollar');
fprintf('\n==== Processed Email ====\n\n');
l = 0;
while ~isempty(email_contents)
    [str, email_contents] = strtok(email_contents, [' @$/#.-:&*+=[]?!(){},''">_<;%' newline char(13)]);
    try str = porterStemmer(strtrim(str)); 
    catch str = ''; continue;
    end
    if length(str) < 1
       continue; end
for i=1:length(vocabList)
    if(strcmp(vocabList{i},str))
        wi = [wi ; i];end;end
    if (l + length(str) + 1) > 78
        fprintf('\n');
        l = 0;end
    fprintf('%s ', str);
    l = l + length(str) + 1;end
fprintf('\n\n=========================\n'); end



function stem = porterStemmer(inString)
inString = lower(inString);
global j;
b = inString;
k = length(b);
k0 = 1;
j = k;
stem = b;
if k > 2
    x = step1ab(b, k, k0);
    x = step1c(x{1}, x{2}, k0);
    x = step2(x{1}, x{2}, k0);
    x = step3(x{1}, x{2}, k0);
    x = step4(x{1}, x{2}, k0);
    x = step5(x{1}, x{2}, k0);
    stem = x{1};end;end
function c = cons(i, b, k0)
c = true;
switch(b(i))
    case {'a', 'e', 'i', 'o', 'u'}
        c = false;
    case 'y'
        if i == k0
            c = true;
        else
            c = ~cons(i - 1, b, k0);
            end;end;end
function n = measure(b, k0)
global j;
n = 0;
i = k0;
while true
    if i > j return; end
    if ~cons(i, b, k0) break; end
    i = i + 1;end
i = i + 1;
while true
    while true
        if i > j return; end
        if cons(i, b, k0)  break; end
        i = i + 1; end
    i = i + 1;
    n = n + 1;
    while true
        if i > j return; end
        if ~cons(i, b, k0) break; end
        i = i + 1; end



    i = i + 1; end;end
function s = ends(str, b, k)
global j;
if (str(length(str)) ~= b(k))
    s = false; return; end
if (length(str) > k)
    s = false; return; end
if strcmp(b(k-length(str)+1:k), str)
    s = true;
    j = k - length(str); return
else s = false; end;end
function so = setto(s, b, k)
global j;
for i = j+1:(j+length(s))
    b(i) = s(i-j); end
if k > j+length(s)
    b((j+length(s)+1):k) = ''; end
k = length(b);
so = {b, k}; end
function s03 = step3(b, k, k0)
global j; s03 = {b, k};
switch b(k)
    case {'e'}
        if ends('icate', b, k) s03 = rs('ic', b, k, k0);
        elseif ends('ative', b, k) s03 = rs('', b, k, k0);
        elseif ends('alize', b, k) s03 = rs('al', b, k, k0); end
    case {'i'}
        if ends('iciti', b, k) s03 = rs('ic', b, k, k0); end
    case {'l'}
        if ends('ical', b, k) s03 = rs('ic', b, k, k0);
        elseif ends('ful', b, k) s03 = rs('', b, k, k0); end
    case {'s'}
        if ends('ness', b, k) s03 = rs('', b, k, k0); end
        end; j = s03{2}; end
function s04 = step4(b, k, k0)
global j;
switch b(k-1)
    case {'a'}
        if ends('al', b, k) end
    case {'c'}
        if ends('ance', b, k)
        elseif ends('ence', b, k) end
    case {'e'}
        if ends('er', b, k) end
    case {'i'}
        if ends('ic', b, k) end
    case {'l'}
        if ends('able', b, k)
        elseif ends('ible', b, k) end
    case {'n'}
        if ends('ant', b, k)
        elseif ends('ement', b, k)
        elseif ends('ment', b, k)
        elseif ends('ent', b, k) end
    case {'o'}
        if ends('ion', b, k)
            if j == 0; elseif ~(strcmp(b(j),'s') || strcmp(b(j),'t'))
                j = k; end
        elseif ends('ou', b, k) end
    case {'s'}
        if ends('ism', b, k) end
    case {'t'}
        if ends('ate', b, k)
        elseif ends('iti', b, k) end
    case {'u'}
        if ends('ous', b, k) end
    case {'v'}
        if ends('ive', b, k) end
    case {'z'}
        if ends('ize', b, k) end
end

if measure(b, k0) > 1 s04 = {b(k0:j), j};
else s04 = {b(k0:k), k};end; end
function sim = linearKernel(x1, x2)
x1 = x1(:); x2 = x2(:);
sim = x1' * x2; end
function vocabList = getVocabList()
fid = fopen('voc.txt');
n = 1899;  
vocabList = cell(n, 1);
for i = 1:n
    fscanf(fid, '%d', 1); vocabList{i} = fscanf(fid, '%s', 1); end
fclose(fid); end
function x = fe(wi)
n = 1899; x = zeros(n, 1);
for i=wi
    x(i) = 1;end; end