function integer log2(input integer n);
    integer i,t;
    begin // this 'begin' can not be omitted
        t = 0;
        for (i = 0; 2 ** i < n; i = i + 1)
            t= i + 1;
        log2 = t;
    end
endfunction
