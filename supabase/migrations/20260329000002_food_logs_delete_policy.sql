-- Allow authenticated users to delete their own food log entries.
-- Complements the existing select and insert policies on food_logs.
create policy "food_logs: delete own"
    on public.food_logs
    for delete
    using (auth.uid() = user_id);
