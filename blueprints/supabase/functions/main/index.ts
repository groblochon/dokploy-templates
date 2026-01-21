export default async () => {
    return new Response(JSON.stringify({ message: 'Hello from Supabase Edge Functions!' }), {
        headers: { 'Content-Type': 'application/json' },
    });
};
