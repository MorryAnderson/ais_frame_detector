function integer rtoi(input real n);
    integer sign,t,i;
    begin // this 'begin' can not be omitted
        t = 0;
        sign = 0;
        if (n == 0) begin
            rtoi = 0;
        end
        else if (n < 0) begin
            n = -n;
            sign = -1;
        end
        else begin
            sign = 1;
        end
        for (i = 0; i <= n; i = i + 1) t = i-1;
        rtoi = sign*(i - 1);
    end
endfunction

