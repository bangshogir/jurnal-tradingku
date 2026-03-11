@extends('layouts.admin')

@section('title', 'Dashboard')
@section('page-title', 'Dashboard Overview')
@section('page-subtitle', 'Ringkasan data trading Anda hari ini')

@section('content')

    {{-- ==================== STAT CARDS ROW 1 ==================== --}}
    <div style="display:grid;grid-template-columns:repeat(2,1fr);gap:12px;margin-bottom:12px;">
        {{-- Total Users --}}
        <div style="background:#fff;border-radius:14px;padding:16px;border:1px solid #f1f5f9;box-shadow:0 1px 3px rgba(0,0,0,.04);">
            <div style="display:flex;align-items:center;gap:8px;margin-bottom:10px;">
                <div style="width:32px;height:32px;background:#eff6ff;border-radius:9px;display:flex;align-items:center;justify-content:center;flex-shrink:0;">
                    <svg width="16" height="16" fill="none" stroke="#4f46e5" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0"/></svg>
                </div>
                <span style="font-size:10.5px;font-weight:700;color:#94a3b8;text-transform:uppercase;letter-spacing:.05em;">Total Users</span>
            </div>
            <p style="font-size:24px;font-weight:800;color:#4f46e5;line-height:1;">{{ number_format($totalUsers) }}</p>
        </div>

        {{-- Total Trades --}}
        <div style="background:#fff;border-radius:14px;padding:16px;border:1px solid #f1f5f9;box-shadow:0 1px 3px rgba(0,0,0,.04);">
            <div style="display:flex;align-items:center;gap:8px;margin-bottom:10px;">
                <div style="width:32px;height:32px;background:#f8fafc;border-radius:9px;display:flex;align-items:center;justify-content:center;flex-shrink:0;">
                    <svg width="16" height="16" fill="none" stroke="#64748b" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2"/></svg>
                </div>
                <span style="font-size:10.5px;font-weight:700;color:#94a3b8;text-transform:uppercase;letter-spacing:.05em;">Total Trades</span>
            </div>
            <p style="font-size:24px;font-weight:800;color:#1e293b;line-height:1;">{{ number_format($totalTrades) }}</p>
        </div>
    </div>

    {{-- ==================== STAT CARDS ROW 2 ==================== --}}
    <div style="display:grid;grid-template-columns:repeat(2,1fr);gap:12px;margin-bottom:12px;">
        {{-- Win Count --}}
        <div style="background:#fff;border-radius:14px;padding:16px;border:1px solid #f1f5f9;box-shadow:0 1px 3px rgba(0,0,0,.04);">
            <div style="display:flex;align-items:center;gap:8px;margin-bottom:10px;">
                <div style="width:32px;height:32px;background:#f0fdf4;border-radius:9px;display:flex;align-items:center;justify-content:center;flex-shrink:0;">
                    <svg width="16" height="16" fill="none" stroke="#16a34a" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"/></svg>
                </div>
                <span style="font-size:10.5px;font-weight:700;color:#94a3b8;text-transform:uppercase;letter-spacing:.05em;">Win</span>
            </div>
            <p style="font-size:24px;font-weight:800;color:#16a34a;line-height:1;">{{ number_format($winCount) }}</p>
            <p style="font-size:11px;color:#94a3b8;margin-top:4px;">Win Rate {{ $winRate }}%</p>
        </div>

        {{-- Loss Count --}}
        <div style="background:#fff;border-radius:14px;padding:16px;border:1px solid #f1f5f9;box-shadow:0 1px 3px rgba(0,0,0,.04);">
            <div style="display:flex;align-items:center;gap:8px;margin-bottom:10px;">
                <div style="width:32px;height:32px;background:#fff1f2;border-radius:9px;display:flex;align-items:center;justify-content:center;flex-shrink:0;">
                    <svg width="16" height="16" fill="none" stroke="#e11d48" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 14l2-2m0 0l2-2m-2 2l-2-2m2 2l2 2m7-2a9 9 0 11-18 0 9 9 0 0118 0z"/></svg>
                </div>
                <span style="font-size:10.5px;font-weight:700;color:#94a3b8;text-transform:uppercase;letter-spacing:.05em;">Loss</span>
            </div>
            <p style="font-size:24px;font-weight:800;color:#e11d48;line-height:1;">{{ number_format($lossCount) }}</p>
            <p style="font-size:11px;color:#94a3b8;margin-top:4px;">Loss Rate {{ $winCount + $lossCount > 0 ? round(($lossCount / ($winCount + $lossCount)) * 100, 1) : 0 }}%</p>
        </div>
    </div>

    {{-- ==================== STAT CARDS ROW 3 ==================== --}}
    <div style="display:grid;grid-template-columns:repeat(2,1fr);gap:12px;margin-bottom:12px;">
        {{-- Total P&L --}}
        <div style="background:#fff;border-radius:14px;padding:16px;border:1px solid #f1f5f9;box-shadow:0 1px 3px rgba(0,0,0,.04);">
            <div style="display:flex;align-items:center;gap:8px;margin-bottom:10px;">
                <div style="width:32px;height:32px;background:{{ $totalProfit >= 0 ? '#f0fdf4' : '#fff1f2' }};border-radius:9px;display:flex;align-items:center;justify-content:center;flex-shrink:0;">
                    <svg width="16" height="16" fill="none" stroke="{{ $totalProfit >= 0 ? '#16a34a' : '#e11d48' }}" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/></svg>
                </div>
                <span style="font-size:10.5px;font-weight:700;color:#94a3b8;text-transform:uppercase;letter-spacing:.05em;">Total P&amp;L</span>
            </div>
            <p style="font-size:22px;font-weight:800;color:{{ $totalProfit >= 0 ? '#16a34a' : '#e11d48' }};line-height:1;">
                {{ $totalProfit >= 0 ? '+' : '-' }}${{ number_format(abs($totalProfit), 2) }}
            </p>
        </div>

        {{-- Today P&L --}}
        <div style="background:#fff;border-radius:14px;padding:16px;border:1px solid #f1f5f9;box-shadow:0 1px 3px rgba(0,0,0,.04);">
            <div style="display:flex;align-items:center;gap:8px;margin-bottom:10px;">
                <div style="width:32px;height:32px;background:#fffbeb;border-radius:9px;display:flex;align-items:center;justify-content:center;flex-shrink:0;">
                    <svg width="16" height="16" fill="none" stroke="#d97706" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"/></svg>
                </div>
                <span style="font-size:10.5px;font-weight:700;color:#94a3b8;text-transform:uppercase;letter-spacing:.05em;">Today P&amp;L</span>
            </div>
            <p style="font-size:22px;font-weight:800;color:{{ $todayProfit >= 0 ? '#16a34a' : '#e11d48' }};line-height:1;">
                {{ $todayProfit >= 0 ? '+' : '-' }}${{ number_format(abs($todayProfit), 2) }}
            </p>
            <p style="font-size:11px;color:#94a3b8;margin-top:4px;">{{ $todayTradesCount }} trades today</p>
        </div>
    </div>

    {{-- ==================== STAT CARDS ROW 4 ==================== --}}
    <div style="display:grid;grid-template-columns:repeat(2,1fr);gap:12px;margin-bottom:16px;">
        {{-- Max Drawdown --}}
        <div style="background:#fff;border-radius:14px;padding:16px;border:1px solid #f1f5f9;box-shadow:0 1px 3px rgba(0,0,0,.04);">
            <div style="display:flex;align-items:center;gap:8px;margin-bottom:10px;">
                <div style="width:32px;height:32px;background:#fff1f2;border-radius:9px;display:flex;align-items:center;justify-content:center;flex-shrink:0;">
                    <svg width="16" height="16" fill="none" stroke="#e11d48" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 17h8m0 0V9m0 8l-8-8-4 4-6-6"/></svg>
                </div>
                <span style="font-size:10.5px;font-weight:700;color:#94a3b8;text-transform:uppercase;letter-spacing:.05em;">Max Drawdown</span>
            </div>
            <p style="font-size:22px;font-weight:800;color:#e11d48;line-height:1;">-${{ number_format($maxDrawdown, 2) }}</p>
        </div>

        {{-- All Time High --}}
        <div style="background:#fff;border-radius:14px;padding:16px;border:1px solid #f1f5f9;box-shadow:0 1px 3px rgba(0,0,0,.04);">
            <div style="display:flex;align-items:center;gap:8px;margin-bottom:10px;">
                <div style="width:32px;height:32px;background:#f0fdf4;border-radius:9px;display:flex;align-items:center;justify-content:center;flex-shrink:0;">
                    <svg width="16" height="16" fill="none" stroke="#16a34a" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 7h8m0 0v8m0-8l-8 8-4-4-6 6"/></svg>
                </div>
                <span style="font-size:10.5px;font-weight:700;color:#94a3b8;text-transform:uppercase;letter-spacing:.05em;">All Time High</span>
            </div>
            <p style="font-size:22px;font-weight:800;color:#16a34a;line-height:1;">+${{ number_format($allTimeHigh, 2) }}</p>
        </div>
    </div>

    {{-- ==================== PROFIT % + WIN RATE BAR ==================== --}}
    <div style="background:#fff;border-radius:14px;padding:16px;border:1px solid #f1f5f9;box-shadow:0 1px 3px rgba(0,0,0,.04);margin-bottom:16px;">
        <div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:12px;">
            <span style="font-size:12px;font-weight:700;color:#1e293b;">Profit Factor</span>
            <span style="font-size:12px;font-weight:700;color:#4f46e5;">{{ $profitPct }}%</span>
        </div>
        <div style="background:#f1f5f9;border-radius:99px;height:8px;overflow:hidden;">
            <div style="background:linear-gradient(90deg,#4f46e5,#06b6d4);height:100%;border-radius:99px;width:{{ $profitPct }}%;transition:width .6s ease;"></div>
        </div>
        <div style="display:flex;align-items:center;justify-content:space-between;margin-top:12px;">
            <span style="font-size:12px;font-weight:700;color:#1e293b;">Win Rate</span>
            <span style="font-size:12px;font-weight:700;color:#16a34a;">{{ $winRate }}%</span>
        </div>
        <div style="background:#f1f5f9;border-radius:99px;height:8px;overflow:hidden;margin-top:6px;">
            <div style="background:linear-gradient(90deg,#16a34a,#86efac);height:100%;border-radius:99px;width:{{ $winRate }}%;transition:width .6s ease;"></div>
        </div>
    </div>

    {{-- ==================== CHART ==================== --}}
    <div style="background:#fff;border-radius:14px;padding:16px;border:1px solid #f1f5f9;box-shadow:0 1px 3px rgba(0,0,0,.04);margin-bottom:20px;">
        <div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:14px;">
            <div>
                <p style="font-size:13px;font-weight:700;color:#1e293b;">Daily P&amp;L (30 Days)</p>
                <p style="font-size:11px;color:#94a3b8;">Profit/Loss per hari</p>
            </div>
        </div>
        <canvas id="dailyPnlChart" style="width:100%;max-height:220px;"></canvas>
    </div>

    {{-- ==================== TRADES TABLE ==================== --}}
    <div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:12px;">
        <h2 style="font-size:14px;font-weight:700;color:#1e293b;">System Wide Logs</h2>
        <button onclick="window.location.reload()"
            style="background:#fff;border:1px solid #e2e8f0;color:#64748b;font-size:11px;font-weight:600;padding:6px 12px;border-radius:8px;cursor:pointer;display:flex;align-items:center;gap:5px;">
            <svg width="12" height="12" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"/></svg>
            Refresh
        </button>
    </div>

    <div style="background:#fff;border-radius:14px;border:1px solid #f1f5f9;box-shadow:0 1px 3px rgba(0,0,0,.04);overflow:hidden;">
        <div style="overflow-x:auto;">
            <table style="min-width:600px;width:100%;font-size:13px;border-collapse:collapse;">
                <thead>
                    <tr style="background:#f8fafc;border-bottom:1px solid #f1f5f9;">
                        <th style="padding:12px 16px;text-align:left;font-size:10.5px;font-weight:700;color:#94a3b8;text-transform:uppercase;letter-spacing:.05em;">Ticket / Pair</th>
                        <th style="padding:12px 16px;text-align:left;font-size:10.5px;font-weight:700;color:#94a3b8;text-transform:uppercase;letter-spacing:.05em;">User</th>
                        <th style="padding:12px 16px;text-align:left;font-size:10.5px;font-weight:700;color:#94a3b8;text-transform:uppercase;letter-spacing:.05em;">Date</th>
                        <th style="padding:12px 16px;text-align:left;font-size:10.5px;font-weight:700;color:#94a3b8;text-transform:uppercase;letter-spacing:.05em;">Type</th>
                        <th style="padding:12px 16px;text-align:left;font-size:10.5px;font-weight:700;color:#94a3b8;text-transform:uppercase;letter-spacing:.05em;">Lot</th>
                        <th style="padding:12px 16px;text-align:left;font-size:10.5px;font-weight:700;color:#94a3b8;text-transform:uppercase;letter-spacing:.05em;">P/L</th>
                        <th style="padding:12px 16px;text-align:left;font-size:10.5px;font-weight:700;color:#94a3b8;text-transform:uppercase;letter-spacing:.05em;">Status</th>
                    </tr>
                </thead>
                <tbody>
                    @forelse ($trades as $trade)
                        <tr style="border-bottom:1px solid #f8fafc;">
                            <td style="padding:12px 16px;">
                                <p style="font-weight:600;color:#1e293b;">{{ $trade->symbol }}</p>
                                <p style="font-size:11px;color:#94a3b8;">#{{ $trade->ticket_id }}</p>
                            </td>
                            <td style="padding:12px 16px;">
                                <p style="font-weight:600;color:#1e293b;">{{ $trade->user->name ?? 'Unknown' }}</p>
                                <p style="font-size:11px;color:#94a3b8;">{{ $trade->user->email ?? '' }}</p>
                            </td>
                            <td style="padding:12px 16px;color:#64748b;">
                                {{ $trade->open_time ? $trade->open_time->format('d M') : '-' }}
                            </td>
                            <td style="padding:12px 16px;">
                                @php
                                    $typeStr = strtolower($trade->type);
                                    $isBuy = str_contains($typeStr, 'buy');
                                    $isSell = str_contains($typeStr, 'sell');
                                    $bg = $isBuy ? '#eff6ff' : ($isSell ? '#fff1f2' : '#f8fafc');
                                    $color = $isBuy ? '#1d4ed8' : ($isSell ? '#be123c' : '#475569');
                                @endphp
                                <span style="background:{{ $bg }};color:{{ $color }};font-size:11px;font-weight:600;padding:3px 8px;border-radius:6px;text-transform:capitalize;">
                                    {{ str_replace('_', ' ', $typeStr) }}
                                </span>
                            </td>
                            <td style="padding:12px 16px;color:#64748b;font-family:monospace;">{{ number_format($trade->lot_size, 2) }}</td>
                            <td style="padding:12px 16px;font-weight:700;">
                                @if (str_contains(strtolower($trade->type), 'closed') || $trade->close_time)
                                    <span style="color:{{ $trade->profit_loss >= 0 ? '#16a34a' : '#e11d48' }}">
                                        {{ $trade->profit_loss >= 0 ? '+' : '-' }}${{ number_format(abs($trade->profit_loss), 2) }}
                                    </span>
                                @else
                                    <span style="color:#94a3b8;">—</span>
                                @endif
                            </td>
                            <td style="padding:12px 16px;">
                                @if (str_contains(strtolower($trade->type), 'closed') || $trade->close_time)
                                    <span style="background:#f0fdf4;color:#16a34a;font-size:11px;font-weight:600;padding:3px 10px;border-radius:6px;display:inline-flex;align-items:center;gap:4px;"><span style="width:6px;height:6px;background:#16a34a;border-radius:50%;"></span>Closed</span>
                                @elseif (str_contains(strtolower($trade->type), 'limit') || str_contains(strtolower($trade->type), 'stop'))
                                    <span style="background:#fffbeb;color:#d97706;font-size:11px;font-weight:600;padding:3px 10px;border-radius:6px;display:inline-flex;align-items:center;gap:4px;"><span style="width:6px;height:6px;background:#d97706;border-radius:50%;"></span>Pending</span>
                                @else
                                    <span style="background:#eff6ff;color:#4f46e5;font-size:11px;font-weight:600;padding:3px 10px;border-radius:6px;display:inline-flex;align-items:center;gap:4px;"><span style="width:6px;height:6px;background:#4f46e5;border-radius:50%;animation:pulse 2s infinite;"></span>Open</span>
                                @endif
                            </td>
                        </tr>
                    @empty
                        <tr>
                            <td colspan="7" style="padding:48px 16px;text-align:center;">
                                <div style="display:flex;flex-direction:column;align-items:center;gap:8px;">
                                    <span style="font-size:32px;">📭</span>
                                    <p style="font-weight:600;color:#475569;">No trades recorded</p>
                                    <p style="font-size:12px;color:#94a3b8;">No users have placed any trades yet.</p>
                                </div>
                            </td>
                        </tr>
                    @endforelse
                </tbody>
            </table>
        </div>
    </div>

    {{-- Chart.js --}}
    <script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.0/dist/chart.umd.min.js"></script>
    <script>
        (function() {
            var chartData = @json($chartData);
            var labels  = chartData.map(function(d) { return d.date; });
            var profits = chartData.map(function(d) { return d.profit; });

            var colors = profits.map(function(v) { return v >= 0 ? 'rgba(22,163,74,.85)' : 'rgba(225,29,72,.85)'; });
            var borders = profits.map(function(v) { return v >= 0 ? '#16a34a' : '#e11d48'; });

            var ctx = document.getElementById('dailyPnlChart');
            if (!ctx) return;

            new Chart(ctx, {
                type: 'bar',
                data: {
                    labels: labels,
                    datasets: [{
                        data: profits,
                        backgroundColor: colors,
                        borderColor: borders,
                        borderWidth: 1.5,
                        borderRadius: 5,
                        borderSkipped: false,
                    }]
                },
                options: {
                    responsive: true,
                    maintainAspectRatio: true,
                    plugins: {
                        legend: { display: false },
                        tooltip: {
                            callbacks: {
                                label: function(c) {
                                    return (c.raw >= 0 ? '+$' : '-$') + Math.abs(c.raw).toFixed(2);
                                }
                            }
                        }
                    },
                    scales: {
                        x: {
                            grid: { display: false },
                            ticks: { font: { size: 10 }, color: '#94a3b8', maxTicksLimit: 8 }
                        },
                        y: {
                            grid: { color: '#f1f5f9' },
                            ticks: {
                                font: { size: 10 }, color: '#94a3b8',
                                callback: function(v) { return '$' + v; }
                            }
                        }
                    }
                }
            });
        })();
    </script>

@endsection
