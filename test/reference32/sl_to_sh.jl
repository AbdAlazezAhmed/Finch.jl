begin
    B_lvl = ex.body.lhs.tns.tns.lvl
    B_lvl_qos_fill = length(B_lvl.tbl)
    B_lvl_qos_stop = B_lvl_qos_fill
    B_lvl_2 = B_lvl.lvl
    A_lvl = ex.body.rhs.tns.tns.lvl
    A_lvl_2 = A_lvl.lvl
    B_lvl_qos_fill = 0
    B_lvl_qos_stop = 0
    empty!(B_lvl.tbl)
    empty!(B_lvl.srt)
    (Finch.resize_if_smaller!)(B_lvl.pos, 1 + 1)
    (Finch.fill_range!)(B_lvl.pos, 0, 1 + 1, 1 + 1)
    B_lvl_qos_fill = length(B_lvl.tbl)
    A_lvl_q = A_lvl.pos[1]
    A_lvl_q_stop = A_lvl.pos[1 + 1]
    A_lvl_i = if A_lvl_q < A_lvl_q_stop
            A_lvl.idx[A_lvl_q]
        else
            1
        end
    A_lvl_i1 = if A_lvl_q < A_lvl_q_stop
            A_lvl.idx[A_lvl_q_stop - 1]
        else
            0
        end
    i = 1
    i_start = i
    phase_stop = (min)(A_lvl.I, A_lvl_i1)
    if phase_stop >= i_start
        i = i
        i = i_start
        while A_lvl_q + 1 < A_lvl_q_stop && A_lvl.idx[A_lvl_q] < i_start
            A_lvl_q += 1
        end
        while i <= phase_stop
            i_start_2 = i
            A_lvl_i = A_lvl.idx[A_lvl_q]
            phase_stop_2 = (min)(A_lvl_i, phase_stop)
            i_2 = i
            if A_lvl_i == phase_stop_2
                A_lvl_2_val_2 = A_lvl_2.val[A_lvl_q]
                i_3 = phase_stop_2
                B_lvl_key = (1, (i_3,))
                B_lvl_q = get(B_lvl.tbl, B_lvl_key, B_lvl_qos_fill + 1)
                if B_lvl_q > B_lvl_qos_stop
                    B_lvl_qos_stop = max(B_lvl_qos_stop << 1, 1)
                    resize_if_smaller!(B_lvl_2.val, B_lvl_qos_stop)
                    fill_range!(B_lvl_2.val, 0.0, B_lvl_q, B_lvl_qos_stop)
                end
                B_lvl_2_dirty = false
                B_lvl_2_val_2 = B_lvl_2.val[B_lvl_q]
                B_lvl_2_dirty = true
                B_lvl_2_dirty = true
                B_lvl_2_val_2 = (+)(A_lvl_2_val_2, B_lvl_2_val_2)
                B_lvl_2.val[B_lvl_q] = B_lvl_2_val_2
                if B_lvl_2_dirty
                    B_lvl_dirty = true
                    if B_lvl_q > B_lvl_qos_fill
                        B_lvl_qos_fill = B_lvl_q
                        B_lvl.tbl[B_lvl_key] = B_lvl_q
                        B_lvl.pos[1 + 1] += 1
                    end
                end
                A_lvl_q += 1
            else
            end
            i = phase_stop_2 + 1
        end
        i = phase_stop + 1
    end
    i_start = i
    if A_lvl.I >= i_start
        i_4 = i
        i = A_lvl.I + 1
    end
    resize!(B_lvl.srt, length(B_lvl.tbl))
    copyto!(B_lvl.srt, pairs(B_lvl.tbl))
    sort!(B_lvl.srt)
    for p = 2:1 + 1
        B_lvl.pos[p] += B_lvl.pos[p - 1]
    end
    qos_stop = B_lvl.pos[1 + 1] - 1
    resize!(B_lvl.pos, 1 + 1)
    qos = B_lvl.pos[end] - 1
    resize!(B_lvl.srt, qos)
    resize!(B_lvl_2.val, qos)
    (B = Fiber((Finch.SparseHashLevel){1, Tuple{Int64}, Int64, Dict{Tuple{Int64, Tuple{Int64}}, Int64}}((A_lvl.I,), B_lvl.tbl, B_lvl.pos, B_lvl.srt, B_lvl_2)),)
end
