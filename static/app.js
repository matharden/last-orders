document.addEventListener('DOMContentLoaded', () => {
    const dataForm = document.getElementById('data-form');
    const refreshBtn = document.getElementById('refresh-btn');
    const logoutBtn = document.getElementById('logout-btn');
    const dataBody = document.getElementById('data-body');
    const cancelBtn = document.getElementById('cancel-btn');
    const submitBtn = document.getElementById('submit-btn');
    const formTitle = document.getElementById('form-title');
    const entryIdInput = document.getElementById('entry-id');

    // Helper to parse "18 Oct" style date string to YYYY-MM-DD
    const parseDateStr = (dateStr) => {
        if (!dateStr) return '';
        if (/^\d{4}-\d{2}-\d{2}$/.test(dateStr)) {
            return dateStr;
        }
        const parts = dateStr.trim().split(/\s+/);
        if (parts.length >= 2) {
            const day = parts[0].padStart(2, '0');
            const monthStr = parts[1].toLowerCase().substring(0, 3);
            const months = {
                jan: '01', feb: '02', mar: '03', apr: '04',
                may: '05', jun: '06', jul: '07', aug: '08',
                sep: '09', oct: '10', nov: '11', dec: '12'
            };
            const month = months[monthStr];
            if (month) {
                const year = new Date().getFullYear();
                return `${year}-${month}-${day}`;
            }
        }
        const today = new Date();
        const yyyy = today.getFullYear();
        const mm = String(today.getMonth() + 1).padStart(2, '0');
        const dd = String(today.getDate()).padStart(2, '0');
        return `${yyyy}-${mm}-${dd}`;
    };

    // Cancel editing
    cancelBtn.addEventListener('click', () => {
        dataForm.reset();
        entryIdInput.value = '';
        cancelBtn.style.display = 'none';
        formTitle.textContent = 'Add Data';
        submitBtn.textContent = 'Add to Sheet';
        setTodayDate();
    });

    // Fetch initial data
    fetchData();
    fetchDrinks();

    // Function to fetch and display autocomplete drinks
    async function fetchDrinks() {
        try {
            const response = await fetch('/api/drinks');
            if (response.ok) {
                const drinks = await response.json();
                const drinkList = document.getElementById('drink-list');
                if (drinkList) {
                    drinkList.innerHTML = '';
                    drinks.forEach(drink => {
                        const option = document.createElement('option');
                        option.value = drink;
                        drinkList.appendChild(option);
                    });
                }
            }
        } catch (error) {
            console.error('Error fetching drinks list:', error);
        }
    }

    // Set default date to today
    const setTodayDate = () => {
        const dateInput = document.getElementById('date');
        if (dateInput) {
            const today = new Date();
            const yyyy = today.getFullYear();
            const mm = String(today.getMonth() + 1).padStart(2, '0');
            const dd = String(today.getDate()).padStart(2, '0');
            dateInput.value = `${yyyy}-${mm}-${dd}`;
        }
    };
    setTodayDate();

    // Handle form submission
    dataForm.addEventListener('submit', async (e) => {
        e.preventDefault();
        
        const date = document.getElementById('date').value;
        const drink = document.getElementById('drink').value;
        const amount = parseFloat(document.getElementById('amount').value);
        const size = parseInt(document.getElementById('size').value, 10);
        const notes = document.getElementById('notes').value;

        const entryId = entryIdInput.value;
        const isEdit = entryId !== '';

        submitBtn.disabled = true;
        submitBtn.textContent = isEdit ? 'Updating...' : 'Adding...';

        try {
            const url = '/api/data';
            const method = isEdit ? 'PUT' : 'POST';
            const payload = {
                date: date,
                drink: drink,
                amount: amount,
                size: size,
                notes: notes
            };
            if (isEdit) {
                payload.id = parseInt(entryId, 10);
            }

            const response = await fetch(url, {
                method: method,
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify(payload)
            });

            if (response.ok) {
                dataForm.reset();
                entryIdInput.value = '';
                cancelBtn.style.display = 'none';
                formTitle.textContent = 'Add Data';
                submitBtn.textContent = 'Add to Sheet';
                setTodayDate();
                await Promise.all([fetchData(), fetchDrinks()]); // Refresh table and autocomplete
            } else if (response.status === 401) {
                window.location.href = '/login';
            } else {
                console.error(`Failed to ${isEdit ? 'update' : 'add'} data`);
                alert(`Failed to ${isEdit ? 'update' : 'add'} data. Please check the server logs.`);
            }
        } catch (error) {
            console.error(`Error ${isEdit ? 'updating' : 'adding'} data:`, error);
            alert('An error occurred. Please try again.');
        } finally {
            submitBtn.disabled = false;
            submitBtn.textContent = isEdit ? 'Update Entry' : 'Add to Sheet';
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
                dataBody.innerHTML = '<tr><td colspan="6" class="text-center">No data found in sheet.</td></tr>';
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
                
                // Actions Column
                const actionTd = document.createElement('td');
                actionTd.className = 'text-center';
                const editBtn = document.createElement('button');
                editBtn.className = 'btn btn-sm edit-btn';
                editBtn.textContent = 'Edit';
                editBtn.addEventListener('click', () => {
                    const id = row[0];
                    const dateVal = row[1] || '';
                    const drinkVal = row[2] || '';
                    const amountVal = row[3] || '';
                    const sizeVal = row[4] || '';
                    const notesVal = row[5] || '';

                    entryIdInput.value = id;
                    document.getElementById('drink').value = drinkVal;
                    document.getElementById('amount').value = amountVal;
                    document.getElementById('size').value = sizeVal;
                    document.getElementById('notes').value = notesVal;

                    const parsedDate = parseDateStr(dateVal);
                    document.getElementById('date').value = parsedDate;

                    formTitle.textContent = 'Edit Entry';
                    submitBtn.textContent = 'Update Entry';
                    cancelBtn.style.display = 'block';

                    window.scrollTo({ top: 0, behavior: 'smooth' });
                });
                actionTd.appendChild(editBtn);
                tr.appendChild(actionTd);
                
                dataBody.appendChild(tr);
            });
        } catch (error) {
            console.error('Error fetching data:', error);
            dataBody.innerHTML = '<tr><td colspan="6" class="text-center text-red-500">Error loading data. Make sure backend is running and authorized.</td></tr>';
        }
    }
});
