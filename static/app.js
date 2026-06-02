document.addEventListener('DOMContentLoaded', () => {
    const dataForm = document.getElementById('data-form');
    const refreshBtn = document.getElementById('refresh-btn');
    const logoutBtn = document.getElementById('logout-btn');
    const dataBody = document.getElementById('data-body');

    // Fetch initial data
    fetchData();

    // Handle form submission
    dataForm.addEventListener('submit', async (e) => {
        e.preventDefault();
        
        const drink = document.getElementById('drink').value;
        const amount = parseFloat(document.getElementById('amount').value);
        const size = parseInt(document.getElementById('size').value, 10);
        const notes = document.getElementById('notes').value;
        const submitBtn = dataForm.querySelector('button[type="submit"]');

        submitBtn.disabled = true;
        submitBtn.textContent = 'Adding...';

        try {
            const response = await fetch('/api/data', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({
                    drink: drink,
                    amount: amount,
                    size: size,
                    notes: notes
                })
            });

            if (response.ok) {
                dataForm.reset();
                await fetchData(); // Refresh table
            } else if (response.status === 401) {
                window.location.href = '/login';
            } else {
                console.error('Failed to add data');
                alert('Failed to add data. Please check the server logs.');
            }
        } catch (error) {
            console.error('Error adding data:', error);
            alert('An error occurred. Please try again.');
        } finally {
            submitBtn.disabled = false;
            submitBtn.textContent = 'Add to Sheet';
        }
    });

    // Handle refresh button
    refreshBtn.addEventListener('click', () => {
        const originalText = refreshBtn.textContent;
        refreshBtn.textContent = 'Refreshing...';
        fetchData().finally(() => {
            refreshBtn.textContent = originalText;
        });
    });

    // Handle logout
    logoutBtn.addEventListener('click', () => {
        window.location.href = '/logout';
    });

    // Function to fetch and display data
    async function fetchData() {
        try {
            const response = await fetch('/api/data');
            
            if (response.status === 401) {
                window.location.href = '/login';
                return;
            }
            
            if (!response.ok) {
                throw new Error('Network response was not ok');
            }
            
            const data = await response.json();
            
            dataBody.innerHTML = '';
            
            if (!data || data.length === 0) {
                dataBody.innerHTML = '<tr><td colspan="5" class="text-center">No data found in sheet.</td></tr>';
                return;
            }

            // Skip first row which contains sheet headers [ID, Drank on, Drink, Amount, Size, Notes]
            const dataRows = data.slice(1);

            dataRows.forEach(row => {
                const tr = document.createElement('tr');
                
                // Columns: Date (1), Drink (2), Amount (3), Size (4), Notes (5)
                const columns = [1, 2, 3, 4, 5];
                columns.forEach(index => {
                    const td = document.createElement('td');
                    td.textContent = row[index] || '';
                    tr.appendChild(td);
                });
                
                dataBody.appendChild(tr);
            });
        } catch (error) {
            console.error('Error fetching data:', error);
            dataBody.innerHTML = '<tr><td colspan="5" class="text-center text-red-500">Error loading data. Make sure backend is running and authorized.</td></tr>';
        }
    }
});
