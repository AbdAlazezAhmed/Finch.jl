begin
    tmp_lvl = (ex.bodies[1]).tns.bind.lvl
    tmp_lvl_2 = tmp_lvl.lvl
    tmp_lvl_ptr = tmp_lvl.lvl.ptr
    tmp_lvl_tbl = tmp_lvl.lvl.tbl
    tmp_lvl_srt = tmp_lvl.lvl.srt
    tmp_lvl_2_qos_stop = (tmp_lvl_2_qos_fill = length(tmp_lvl_2.srt))
    tmp_lvl_3 = tmp_lvl_2.lvl
    tmp_lvl_2_val = tmp_lvl_2.lvl.val
    ref_lvl = (ex.bodies[2]).body.body.rhs.tns.bind.lvl
    ref_lvl_ptr = ref_lvl.ptr
    ref_lvl_idx = ref_lvl.idx
    ref_lvl_2 = ref_lvl.lvl
    ref_lvl_ptr_2 = ref_lvl_2.ptr
    ref_lvl_idx_2 = ref_lvl_2.idx
    ref_lvl_2_val = ref_lvl_2.lvl.val
    for tmp_lvl_2_r = 1:tmp_lvl_2_qos_fill
        tmp_lvl_2_p = first(tmp_lvl_srt[tmp_lvl_2_r])
        tmp_lvl_ptr[tmp_lvl_2_p] = 0
        tmp_lvl_ptr[tmp_lvl_2_p + 1] = 0
        tmp_lvl_2_i = last(tmp_lvl_srt[tmp_lvl_2_r])
        tmp_lvl_2_q = (tmp_lvl_2_p - 1) * ref_lvl_2.shape + tmp_lvl_2_i
        tmp_lvl_tbl[tmp_lvl_2_q] = false
        Finch.resize_if_smaller!(tmp_lvl_2_val, tmp_lvl_2_q)
        Finch.fill_range!(tmp_lvl_2_val, false, tmp_lvl_2_q, tmp_lvl_2_q)
    end
    tmp_lvl_2_qos_fill = 0
    tmp_lvl_ptr[1] = 1
    p_start_2 = ref_lvl.shape
    tmp_lvl_2q_start = (1 - 1) * ref_lvl_2.shape + 1
    tmp_lvl_2q_stop = p_start_2 * ref_lvl_2.shape
    Finch.resize_if_smaller!(tmp_lvl_ptr, p_start_2 + 1)
    Finch.fill_range!(tmp_lvl_ptr, 0, 1 + 1, p_start_2 + 1)
    Finch.resize_if_smaller!(tmp_lvl_tbl, tmp_lvl_2q_stop)
    Finch.fill_range!(tmp_lvl_tbl, false, tmp_lvl_2q_start, tmp_lvl_2q_stop)
    Finch.resize_if_smaller!(tmp_lvl_2_val, tmp_lvl_2q_stop)
    Finch.fill_range!(tmp_lvl_2_val, false, tmp_lvl_2q_start, tmp_lvl_2q_stop)
    ref_lvl_q = ref_lvl_ptr[1]
    ref_lvl_q_stop = ref_lvl_ptr[1 + 1]
    if ref_lvl_q < ref_lvl_q_stop
        ref_lvl_i1 = ref_lvl_idx[ref_lvl_q_stop - 1]
    else
        ref_lvl_i1 = 0
    end
    phase_stop = min(ref_lvl.shape, ref_lvl_i1)
    if phase_stop >= 1
        if ref_lvl_idx[ref_lvl_q] < 1
            ref_lvl_q = Finch.scansearch(ref_lvl_idx, 1, ref_lvl_q, ref_lvl_q_stop - 1)
        end
        while true
            ref_lvl_i = ref_lvl_idx[ref_lvl_q]
            if ref_lvl_i < phase_stop
                tmp_lvl_q = (1 - 1) * ref_lvl.shape + ref_lvl_i
                ref_lvl_2_q = ref_lvl_ptr_2[ref_lvl_q]
                ref_lvl_2_q_stop = ref_lvl_ptr_2[ref_lvl_q + 1]
                if ref_lvl_2_q < ref_lvl_2_q_stop
                    ref_lvl_2_i1 = ref_lvl_idx_2[ref_lvl_2_q_stop - 1]
                else
                    ref_lvl_2_i1 = 0
                end
                phase_stop_3 = min(ref_lvl_2_i1, ref_lvl_2.shape)
                if phase_stop_3 >= 1
                    if ref_lvl_idx_2[ref_lvl_2_q] < 1
                        ref_lvl_2_q = Finch.scansearch(ref_lvl_idx_2, 1, ref_lvl_2_q, ref_lvl_2_q_stop - 1)
                    end
                    while true
                        ref_lvl_2_i = ref_lvl_idx_2[ref_lvl_2_q]
                        if ref_lvl_2_i < phase_stop_3
                            ref_lvl_3_val = ref_lvl_2_val[ref_lvl_2_q]
                            tmp_lvl_2_q_2 = (tmp_lvl_q - 1) * ref_lvl_2.shape + ref_lvl_2_i
                            tmp_lvl_2_val[tmp_lvl_2_q_2] = ref_lvl_3_val
                            if !(tmp_lvl_tbl[tmp_lvl_2_q_2])
                                tmp_lvl_tbl[tmp_lvl_2_q_2] = true
                                tmp_lvl_2_qos_fill += 1
                                if tmp_lvl_2_qos_fill > tmp_lvl_2_qos_stop
                                    tmp_lvl_2_qos_stop = max(tmp_lvl_2_qos_stop << 1, 1)
                                    Finch.resize_if_smaller!(tmp_lvl_srt, tmp_lvl_2_qos_stop)
                                end
                                tmp_lvl_srt[tmp_lvl_2_qos_fill] = (tmp_lvl_q, ref_lvl_2_i)
                            end
                            ref_lvl_2_q += 1
                        else
                            phase_stop_5 = min(phase_stop_3, ref_lvl_2_i)
                            if ref_lvl_2_i == phase_stop_5
                                ref_lvl_3_val = ref_lvl_2_val[ref_lvl_2_q]
                                tmp_lvl_2_q_2 = (tmp_lvl_q - 1) * ref_lvl_2.shape + phase_stop_5
                                tmp_lvl_2_val[tmp_lvl_2_q_2] = ref_lvl_3_val
                                if !(tmp_lvl_tbl[tmp_lvl_2_q_2])
                                    tmp_lvl_tbl[tmp_lvl_2_q_2] = true
                                    tmp_lvl_2_qos_fill += 1
                                    if tmp_lvl_2_qos_fill > tmp_lvl_2_qos_stop
                                        tmp_lvl_2_qos_stop = max(tmp_lvl_2_qos_stop << 1, 1)
                                        Finch.resize_if_smaller!(tmp_lvl_srt, tmp_lvl_2_qos_stop)
                                    end
                                    tmp_lvl_srt[tmp_lvl_2_qos_fill] = (tmp_lvl_q, phase_stop_5)
                                end
                                ref_lvl_2_q += 1
                            end
                            break
                        end
                    end
                end
                ref_lvl_q += 1
            else
                phase_stop_6 = min(phase_stop, ref_lvl_i)
                if ref_lvl_i == phase_stop_6
                    tmp_lvl_q = (1 - 1) * ref_lvl.shape + phase_stop_6
                    ref_lvl_2_q = ref_lvl_ptr_2[ref_lvl_q]
                    ref_lvl_2_q_stop = ref_lvl_ptr_2[ref_lvl_q + 1]
                    if ref_lvl_2_q < ref_lvl_2_q_stop
                        ref_lvl_2_i1 = ref_lvl_idx_2[ref_lvl_2_q_stop - 1]
                    else
                        ref_lvl_2_i1 = 0
                    end
                    phase_stop_7 = min(ref_lvl_2_i1, ref_lvl_2.shape)
                    if phase_stop_7 >= 1
                        if ref_lvl_idx_2[ref_lvl_2_q] < 1
                            ref_lvl_2_q = Finch.scansearch(ref_lvl_idx_2, 1, ref_lvl_2_q, ref_lvl_2_q_stop - 1)
                        end
                        while true
                            ref_lvl_2_i = ref_lvl_idx_2[ref_lvl_2_q]
                            if ref_lvl_2_i < phase_stop_7
                                ref_lvl_3_val_2 = ref_lvl_2_val[ref_lvl_2_q]
                                tmp_lvl_2_q_3 = (tmp_lvl_q - 1) * ref_lvl_2.shape + ref_lvl_2_i
                                tmp_lvl_2_val[tmp_lvl_2_q_3] = ref_lvl_3_val_2
                                if !(tmp_lvl_tbl[tmp_lvl_2_q_3])
                                    tmp_lvl_tbl[tmp_lvl_2_q_3] = true
                                    tmp_lvl_2_qos_fill += 1
                                    if tmp_lvl_2_qos_fill > tmp_lvl_2_qos_stop
                                        tmp_lvl_2_qos_stop = max(tmp_lvl_2_qos_stop << 1, 1)
                                        Finch.resize_if_smaller!(tmp_lvl_srt, tmp_lvl_2_qos_stop)
                                    end
                                    tmp_lvl_srt[tmp_lvl_2_qos_fill] = (tmp_lvl_q, ref_lvl_2_i)
                                end
                                ref_lvl_2_q += 1
                            else
                                phase_stop_9 = min(ref_lvl_2_i, phase_stop_7)
                                if ref_lvl_2_i == phase_stop_9
                                    ref_lvl_3_val_2 = ref_lvl_2_val[ref_lvl_2_q]
                                    tmp_lvl_2_q_3 = (tmp_lvl_q - 1) * ref_lvl_2.shape + phase_stop_9
                                    tmp_lvl_2_val[tmp_lvl_2_q_3] = ref_lvl_3_val_2
                                    if !(tmp_lvl_tbl[tmp_lvl_2_q_3])
                                        tmp_lvl_tbl[tmp_lvl_2_q_3] = true
                                        tmp_lvl_2_qos_fill += 1
                                        if tmp_lvl_2_qos_fill > tmp_lvl_2_qos_stop
                                            tmp_lvl_2_qos_stop = max(tmp_lvl_2_qos_stop << 1, 1)
                                            Finch.resize_if_smaller!(tmp_lvl_srt, tmp_lvl_2_qos_stop)
                                        end
                                        tmp_lvl_srt[tmp_lvl_2_qos_fill] = (tmp_lvl_q, phase_stop_9)
                                    end
                                    ref_lvl_2_q += 1
                                end
                                break
                            end
                        end
                    end
                    ref_lvl_q += 1
                end
                break
            end
        end
    end
    sort!(view(tmp_lvl_srt, 1:tmp_lvl_2_qos_fill))
    tmp_lvl_2_p_prev = 0
    for tmp_lvl_2_r_2 = 1:tmp_lvl_2_qos_fill
        tmp_lvl_2_p_2 = first(tmp_lvl_srt[tmp_lvl_2_r_2])
        if tmp_lvl_2_p_2 != tmp_lvl_2_p_prev
            tmp_lvl_ptr[tmp_lvl_2_p_prev + 1] = tmp_lvl_2_r_2
            tmp_lvl_ptr[tmp_lvl_2_p_2] = tmp_lvl_2_r_2
        end
        tmp_lvl_2_p_prev = tmp_lvl_2_p_2
    end
    tmp_lvl_ptr[tmp_lvl_2_p_2 + 1] = tmp_lvl_2_qos_fill + 1
    qos = 1 * ref_lvl.shape
    resize!(tmp_lvl_ptr, qos + 1)
    resize!(tmp_lvl_tbl, qos * ref_lvl_2.shape)
    resize!(tmp_lvl_srt, tmp_lvl_2_qos_fill)
    resize!(tmp_lvl_2_val, qos * ref_lvl_2.shape)
    (tmp = Fiber((DenseLevel){Int32}((SparseByteMapLevel){Int32}(tmp_lvl_3, ref_lvl_2.shape, tmp_lvl_ptr, tmp_lvl_tbl, tmp_lvl_srt), ref_lvl.shape)),)
end
