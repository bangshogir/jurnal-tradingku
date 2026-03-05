<!DOCTYPE html>
<html lang="en">

<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Trading Journal Dashboard</title>
    <!-- Tailwind CSS (via CDN purely for ease of setup; usually you compile with Vite/Mix) -->
    <script src="https://cdn.tailwindcss.com"></script>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap" rel="stylesheet">
    <style>
        body {
            font-family: 'Inter', sans-serif;
            background-color: #f3f4f6;
        }
    </style>
</head>

<body class="antialiased">

    <div class="min-h-screen">
        <!-- Navigation -->
        <nav class="bg-gray-900 border-b border-gray-800">
            <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
                <div class="flex items-center justify-between h-16">
                    <div class="flex items-center">
                        <div class="flex-shrink-0 text-white font-bold text-xl tracking-tight">
                            📈 Jurnal Tradingku
                        </div>
                    </div>
                </div>
            </div>
        </nav>

        <!-- Main Content -->
        <main class="max-w-7xl mx-auto py-8 px-4 sm:px-6 lg:px-8">

            <!-- Header Section -->
            <div class="md:flex md:items-center md:justify-between mb-8">
                <div class="flex-1 min-w-0">
                    <h2 class="text-2xl font-bold leading-7 text-gray-900 sm:text-3xl sm:truncate">
                        Dashboard Overview
                    </h2>
                </div>
                <div class="mt-4 flex md:mt-0 md:ml-4">
                    <button type="button" onclick="window.location.reload()"
                        class="inline-flex items-center px-4 py-2 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500">
                        <svg class="-ml-1 mr-2 h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                                d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
                        </svg>
                        Refresh Data
                    </button>
                </div>
            </div>

            <!-- Stats Grid (6 Cards) -->
            <dl class="mt-5 grid grid-cols-2 gap-5 sm:grid-cols-3 lg:grid-cols-6 mb-8">
                <div
                    class="px-4 py-5 bg-white shadow rounded-lg overflow-hidden sm:p-6 transition transform hover:-translate-y-1 hover:shadow-lg duration-200">
                    <dt class="text-sm font-medium text-gray-500 truncate">Total Trades</dt>
                    <dd class="mt-1 text-2xl font-semibold text-gray-900">{{ number_format($totalTrades) }}</dd>
                </div>

                <div
                    class="px-4 py-5 bg-white shadow rounded-lg overflow-hidden sm:p-6 transition transform hover:-translate-y-1 hover:shadow-lg duration-200">
                    <dt class="text-sm font-medium text-gray-500 truncate">Today Trades</dt>
                    <dd class="mt-1 text-2xl font-semibold text-gray-900">{{ number_format($todayTradesCount) }}</dd>
                </div>

                <div
                    class="px-4 py-5 bg-white shadow rounded-lg overflow-hidden sm:p-6 transition transform hover:-translate-y-1 hover:shadow-lg duration-200">
                    <dt class="text-sm font-medium text-gray-500 truncate">All PnL</dt>
                    <dd class="mt-1 text-2xl font-semibold {{ $totalProfit >= 0 ? 'text-green-600' : 'text-red-600' }}">
                        {{ $totalProfit >= 0 ? '+' : '' }}${{ number_format($totalProfit, 2) }}
                    </dd>
                </div>

                <div
                    class="px-4 py-5 bg-white shadow rounded-lg overflow-hidden sm:p-6 transition transform hover:-translate-y-1 hover:shadow-lg duration-200">
                    <dt class="text-sm font-medium text-gray-500 truncate">Today PnL</dt>
                    <dd class="mt-1 text-2xl font-semibold {{ $todayProfit >= 0 ? 'text-green-600' : 'text-red-600' }}">
                        {{ $todayProfit >= 0 ? '+' : '' }}${{ number_format($todayProfit, 2) }}
                    </dd>
                </div>

                <div
                    class="px-4 py-5 bg-white shadow rounded-lg overflow-hidden sm:p-6 transition transform hover:-translate-y-1 hover:shadow-lg duration-200">
                    <dt class="text-sm font-medium text-gray-500 truncate">Win Rate</dt>
                    <dd class="mt-1 text-2xl font-semibold text-gray-900">{{ $winRate }}%</dd>
                </div>

                <div
                    class="px-4 py-5 bg-white shadow rounded-lg overflow-hidden sm:p-6 transition transform hover:-translate-y-1 hover:shadow-lg duration-200">
                    <dt class="text-sm font-medium text-gray-500 truncate">Balance</dt>
                    <dd class="mt-1 text-2xl font-semibold text-gray-900">
                        <!-- Assuming $currentBalance is either the actual balance passing or the calculated profit sum -->
                        ${{ number_format($currentBalance, 2) }}
                    </dd>
                </div>
            </dl>

            <!-- Data Table -->
            <div class="flex flex-col">
                <div class="-my-2 overflow-x-auto sm:-mx-6 lg:-mx-8">
                    <div class="py-2 align-middle inline-block min-w-full sm:px-6 lg:px-8">
                        <div class="shadow overflow-hidden border-b border-gray-200 sm:rounded-lg">
                            <table class="min-w-full divide-y divide-gray-200">
                                <thead class="bg-gray-50">
                                    <tr>
                                        <th scope="col"
                                            class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                                            Time/Tanggal</th>
                                        <th scope="col"
                                            class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                                            Pair</th>
                                        <th scope="col"
                                            class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                                            Type</th>
                                        <th scope="col"
                                            class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                                            Volume (Lot)</th>
                                        <th scope="col"
                                            class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                                            Entry Price</th>
                                        <th scope="col"
                                            class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                                            SL Price</th>
                                        <th scope="col"
                                            class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                                            TP Price</th>
                                        <th scope="col"
                                            class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                                            Profit/Loss</th>
                                    </tr>
                                </thead>
                                <tbody class="bg-white divide-y divide-gray-200">
                                    @forelse ($trades as $trade)
                                        <tr class="hover:bg-gray-50 transition duration-150">
                                            <td class="px-6 py-4 whitespace-nowrap text-xs text-gray-500">
                                                <div class="flex flex-col">
                                                    <span>{{ $trade->open_time ? $trade->open_time->format('d M y, H:i') : '-' }}</span>
                                                    <span class="text-xs text-gray-400">→
                                                        {{ $trade->close_time ? $trade->close_time->format('d M y, H:i') : $trade->created_at->format('d M y, H:i') }}</span>
                                                </div>
                                            </td>
                                            <td class="px-6 py-4 whitespace-nowrap">
                                                <div class="text-sm font-medium text-gray-900">{{ $trade->symbol }}
                                                </div>
                                                <div class="text-xs text-gray-500">#{{ $trade->ticket_id }}</div>
                                            </td>
                                            <td class="px-6 py-4 whitespace-nowrap">
                                                @if (str_contains(strtolower($trade->type), 'buy'))
                                                    <span
                                                        class="px-2 inline-flex text-xs leading-5 font-semibold rounded-full bg-blue-100 text-blue-800">{{ str_replace('_', ' ', strtoupper($trade->type)) }}</span>
                                                @else
                                                    <span
                                                        class="px-2 inline-flex text-xs leading-5 font-semibold rounded-full bg-orange-100 text-orange-800">{{ str_replace('_', ' ', strtoupper($trade->type)) }}</span>
                                                @endif
                                            </td>
                                            <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                                                {{ number_format($trade->lot_size, 2) }}
                                            </td>
                                            <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                                                {{ number_format($trade->entry_price, 5) }}
                                            </td>
                                            <td class="px-6 py-4 whitespace-nowrap text-sm">
                                                @php
                                                    // Optional visualization: highlight if price touched SL
                                                    $slColor = 'text-gray-500';
                                                    if (
                                                        $trade->sl_price > 0 &&
                                                        abs($trade->close_price - $trade->sl_price) <= 0.0005
                                                    ) {
                                                        $slColor = 'text-red-600 font-bold';
                                                    }
                                                @endphp
                                                <span class="{{ $slColor }}">
                                                    {{ $trade->sl_price > 0 ? number_format($trade->sl_price, 5) : '-' }}
                                                </span>
                                            </td>
                                            <td class="px-6 py-4 whitespace-nowrap text-sm">
                                                @php
                                                    // Optional visualization: highlight if price touched TP
                                                    $tpColor = 'text-gray-500';
                                                    if (
                                                        $trade->tp_price > 0 &&
                                                        abs($trade->close_price - $trade->tp_price) <= 0.0005
                                                    ) {
                                                        $tpColor = 'text-green-600 font-bold';
                                                    }
                                                @endphp
                                                <span class="{{ $tpColor }}">
                                                    {{ $trade->tp_price > 0 ? number_format($trade->tp_price, 5) : '-' }}
                                                </span>
                                            </td>
                                            <td class="px-6 py-4 whitespace-nowrap">
                                                @if ($trade->profit_loss >= 0)
                                                    <span
                                                        class="px-3 py-1 inline-flex text-sm leading-5 font-bold rounded bg-green-100 text-green-800 border border-green-200 shadow-sm">
                                                        +${{ number_format($trade->profit_loss, 2) }}
                                                    </span>
                                                @else
                                                    <span
                                                        class="px-3 py-1 inline-flex text-sm leading-5 font-bold rounded bg-red-100 text-red-800 border border-red-200 shadow-sm">
                                                        -${{ number_format(abs($trade->profit_loss), 2) }}
                                                    </span>
                                                @endif
                                            </td>
                                        </tr>
                                    @empty
                                        <tr>
                                            <td colspan="8" class="px-6 py-10 text-center text-sm text-gray-500">
                                                No trading logs found. Waiting for MT5 Webhook Data. ⏳
                                            </td>
                                        </tr>
                                    @endforelse
                                </tbody>
                            </table>
                        </div>
                    </div>
                </div>
            </div>

        </main>
    </div>

</body>

</html>
