begin
    B = ex.body.body.lhs.tns.tns
    A_lvl = ex.body.body.rhs.tns.tns.lvl
    A_lvl_2 = A_lvl.lvl
    A_lvl_3 = A_lvl_2.lvl
    (B_mode1_stop,) = size(B)
    (B_mode1_stop,) = size(B)
    (B_mode1_stop,) = size(B)
    1 == 1 || throw(DimensionMismatch("mismatched dimension start"))
    A_lvl_2.I == B_mode1_stop || throw(DimensionMismatch("mismatched dimension stop"))
    fill!(B, 0)
    for j = 1:A_lvl.I
        A_lvl_q = (1 - 1) * A_lvl.I + j
        A_lvl_2_q = A_lvl_2.pos[A_lvl_q]
        A_lvl_2_q_stop = A_lvl_2.pos[A_lvl_q + 1]
        A_lvl_2_i = if A_lvl_2_q < A_lvl_2_q_stop
                A_lvl_2.idx[A_lvl_2_q]
            else
                1
            end
        A_lvl_2_i1 = if A_lvl_2_q < A_lvl_2_q_stop
                A_lvl_2.idx[A_lvl_2_q_stop - 1]
            else
                0
            end
        i = 1
        i_start = i
        phase_stop = (min)(A_lvl_2.I, A_lvl_2_i1)
        if phase_stop >= i_start
            i = i
            i = i_start
            while A_lvl_2_q + 1 < A_lvl_2_q_stop && A_lvl_2.idx[A_lvl_2_q] < i_start
                A_lvl_2_q += 1
            end
            while i <= phase_stop
                i_start_2 = i
                A_lvl_2_i = A_lvl_2.idx[A_lvl_2_q]
                phase_stop_2 = (min)(A_lvl_2_i, phase_stop)
                i_2 = i
                if A_lvl_2_i == phase_stop_2
                    A_lvl_3_val_2 = A_lvl_3.val[A_lvl_2_q]
                    i_3 = phase_stop_2
                    B[i_3] = (+)(A_lvl_3_val_2, B[i_3])
                    A_lvl_2_q += 1
                else
                end
                i = phase_stop_2 + 1
            end
            i = phase_stop + 1
        end
        i_start = i
        if A_lvl_2.I >= i_start
            i_4 = i
            i = A_lvl_2.I + 1
        end
    end
    (B = B,)
end