-- Internal helper used only inside the school run RPCs (owner context).
revoke execute on function public.fn_my_open_run(uuid) from authenticated;
