<script>
  import { onMount } from 'svelte';

  let data = [];
  let drinks = [];
  let loading = true;
  let errorMsg = '';

  // Form state
  let entryId = '';
  let date = '';
  let drink = '';
  let amount = '';
  let size = '';
  let notes = '';
  let isSubmitting = false;

  // Derived states
  $: isEdit = entryId !== '';

  // Helper to parse date string to YYYY-MM-DD
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
    return getTodayDate();
  };

  const getTodayDate = () => {
    const today = new Date();
    const yyyy = today.getFullYear();
    const mm = String(today.getMonth() + 1).padStart(2, '0');
    const dd = String(today.getDate()).padStart(2, '0');
    return `${yyyy}-${mm}-${dd}`;
  };

  const resetForm = () => {
    entryId = '';
    drink = '';
    amount = '';
    size = '';
    notes = '';
    date = getTodayDate();
  };

  const handleAuthError = (res) => {
    if (res.status === 401) {
      window.location.href = '/login';
      return true;
    }
    return false;
  };

  const fetchData = async () => {
    loading = true;
    errorMsg = '';
    try {
      const res = await fetch('/api/data');
      if (handleAuthError(res)) return;

      if (!res.ok) throw new Error('Failed to fetch data');
      const result = await res.json();

      if (!result || result.length === 0) {
        data = [];
      } else {
        // Skip header row and reverse
        data = result.slice(1).reverse();
      }
    } catch (err) {
      console.error(err);
      errorMsg = 'Error loading data. Make sure backend is running and authorized.';
    } finally {
      loading = false;
    }
  };

  const fetchDrinks = async () => {
    try {
      const res = await fetch('/api/drinks');
      if (res.ok) {
        drinks = await res.json();
      }
    } catch (err) {
      console.error('Error fetching drinks:', err);
    }
  };

  const refreshData = async () => {
    await Promise.all([fetchData(), fetchDrinks()]);
  };

  onMount(() => {
    resetForm();
    refreshData();
  });

  const submitForm = async () => {
    isSubmitting = true;
    const method = isEdit ? 'PUT' : 'POST';

    const payload = {
      date,
      drink,
      amount: parseFloat(amount),
      size: parseInt(size, 10),
      notes
    };

    if (isEdit) {
      payload.id = parseInt(entryId, 10);
    }

    try {
      const res = await fetch('/api/data', {
        method,
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload)
      });

      if (handleAuthError(res)) return;

      if (res.ok) {
        resetForm();
        await refreshData();
      } else {
        alert(`Failed to ${isEdit ? 'update' : 'add'} data.`);
      }
    } catch (err) {
      console.error(err);
      alert('An error occurred. Please try again.');
    } finally {
      isSubmitting = false;
    }
  };

  const editEntry = (row) => {
    entryId = row[0];
    date = parseDateStr(row[1] || '');
    drink = row[2] || '';
    amount = row[3] || '';
    size = row[4] || '';
    notes = row[5] || '';
    window.scrollTo({ top: 0, behavior: 'smooth' });
  };

  const deleteEntry = async (id, drinkName) => {
    if (!confirm(`Are you sure you want to delete "${drinkName}"?`)) return;

    try {
      const res = await fetch(`/api/data?id=${id}`, { method: 'DELETE' });
      if (handleAuthError(res)) return;

      if (res.ok) {
        if (entryId === id) resetForm();
        await refreshData();
      } else {
        alert('Failed to delete item.');
      }
    } catch (err) {
      console.error(err);
      alert('An error occurred. Please try again.');
    }
  };
</script>

<div class="app-container">
  <header>
    <h1>Boozer Dashboard</h1>
    <button on:click={() => window.location.href = '/logout'} class="btn secondary">Logout</button>
  </header>

  <main>
    <section class="card glass">
      <h2>{isEdit ? 'Edit Entry' : 'Add Data'}</h2>
      <form on:submit|preventDefault={submitForm}>
        <div class="form-group">
          <label for="date">Date</label>
          <input type="date" id="date" bind:value={date} required>
        </div>
        <div class="form-group">
          <label for="drink">Drink</label>
          <input type="text" id="drink" bind:value={drink} list="drink-list" required placeholder="e.g. Camden Ale">
          <datalist id="drink-list">
            {#each drinks as d}
            <option value={d}></option>
            {/each}
          </datalist>
        </div>
        <div class="form-group">
          <label for="amount">Amount</label>
          <input type="number" id="amount" bind:value={amount} required step="any" placeholder="e.g. 1">
        </div>
        <div class="form-group">
          <label for="size">Size (ml)</label>
          <input type="number" id="size" bind:value={size} required placeholder="e.g. 330">
        </div>
        <div class="form-group">
          <label for="notes">Notes</label>
          <input type="text" id="notes" bind:value={notes} placeholder="e.g. delicious, hoppy">
        </div>
        <div class="form-actions">
          <button type="submit" disabled={isSubmitting} class="btn primary">
            {isSubmitting ? (isEdit ? 'Updating...' : 'Adding...') : (isEdit ? 'Update Entry' : 'Add to Sheet')}
          </button>
          {#if isEdit}
          <button type="button" on:click={resetForm} class="btn secondary">Cancel</button>
          {/if}
        </div>
      </form>
    </section>

    <section class="card glass mt-2">
      <h2>Current Data</h2>
      <div class="table-container">
        <table>
          <thead>
            <tr>
              <th>Date</th>
              <th>Drink</th>
              <th>Amount</th>
              <th>Size</th>
              <th>Notes</th>
              <th class="text-center">Actions</th>
            </tr>
          </thead>
          <tbody>
            {#if loading}
            <tr><td colspan="6" class="text-center">Loading data...</td></tr>
            {:else if errorMsg}
            <tr><td colspan="6" class="text-center text-red-500">{errorMsg}</td></tr>
            {:else if data.length === 0}
            <tr><td colspan="6" class="text-center">No data found in sheet.</td></tr>
            {:else}
            {#each data as row}
            <tr>
              <td>{row[1] || ''}</td>
              <td>{row[2] || ''}</td>
              <td>{row[3] || ''}</td>
              <td>{row[4] || ''}</td>
              <td>{row[5] || ''}</td>
              <td class="text-center">
                <div class="actions-cell">
                  <button on:click={() => editEntry(row)} class="btn btn-sm edit-btn">Edit</button>
                  <button on:click={() => deleteEntry(row[0], row[2] || 'this item')} class="btn btn-sm delete-btn">Delete</button>
                </div>
              </td>
            </tr>
            {/each}
            {/if}
          </tbody>
        </table>
      </div>
      <button on:click={refreshData} class="btn secondary mt-1">
        {loading ? 'Refreshing...' : 'Refresh Data'}
      </button>
    </section>
  </main>
</div>
