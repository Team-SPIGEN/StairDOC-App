#!/usr/bin/env python3
"""
Load testing script for StairDOC API.

Verifies the database can handle 1000+ requests/min (17+ req/sec).

Usage:
    python -m scripts.load_test --url http://localhost:8000 --requests 1000 --concurrency 50
"""

import argparse
import asyncio
import statistics
import time
from dataclasses import dataclass
from typing import Optional

import aiohttp


@dataclass
class TestResult:
    """Result of a single request."""
    latency_ms: float
    status: int
    success: bool
    error: Optional[str] = None


@dataclass
class LoadTestReport:
    """Summary report of load test."""
    total_requests: int
    successful: int
    failed: int
    total_time_sec: float
    requests_per_second: float
    avg_latency_ms: float
    min_latency_ms: float
    max_latency_ms: float
    p50_latency_ms: float
    p95_latency_ms: float
    p99_latency_ms: float
    
    def __str__(self) -> str:
        return f"""
╔══════════════════════════════════════════════════════════════╗
║                   LOAD TEST REPORT                           ║
╠══════════════════════════════════════════════════════════════╣
║  Total Requests:     {self.total_requests:>8}                            ║
║  Successful:         {self.successful:>8}                            ║
║  Failed:             {self.failed:>8}                            ║
║  Total Time:         {self.total_time_sec:>8.2f} sec                       ║
╠══════════════════════════════════════════════════════════════╣
║  Requests/Second:    {self.requests_per_second:>8.2f} (Target: 17+)           ║
║  Requests/Minute:    {self.requests_per_second * 60:>8.0f} (Target: 1000+)         ║
╠══════════════════════════════════════════════════════════════╣
║  Latency (ms):                                               ║
║    Average:          {self.avg_latency_ms:>8.2f}                            ║
║    Min:              {self.min_latency_ms:>8.2f}                            ║
║    Max:              {self.max_latency_ms:>8.2f}                            ║
║    P50:              {self.p50_latency_ms:>8.2f}                            ║
║    P95:              {self.p95_latency_ms:>8.2f}                            ║
║    P99:              {self.p99_latency_ms:>8.2f}                            ║
╠══════════════════════════════════════════════════════════════╣
║  Status:             {'✓ PASSED' if self.requests_per_second >= 17 else '✗ FAILED':>8}                            ║
╚══════════════════════════════════════════════════════════════╝
"""


async def make_request(
    session: aiohttp.ClientSession,
    url: str,
    method: str = "GET",
    json_data: Optional[dict] = None,
) -> TestResult:
    """Make a single HTTP request and measure latency."""
    start = time.perf_counter()
    try:
        async with session.request(method, url, json=json_data) as response:
            await response.read()
            latency = (time.perf_counter() - start) * 1000
            return TestResult(
                latency_ms=latency,
                status=response.status,
                success=200 <= response.status < 300,
            )
    except Exception as e:
        latency = (time.perf_counter() - start) * 1000
        return TestResult(
            latency_ms=latency,
            status=0,
            success=False,
            error=str(e),
        )


async def run_load_test(
    base_url: str,
    num_requests: int,
    concurrency: int,
    endpoint: str = "/health",
) -> LoadTestReport:
    """Run load test with specified parameters."""
    url = f"{base_url.rstrip('/')}{endpoint}"
    results: list[TestResult] = []
    
    # Create connection pool
    connector = aiohttp.TCPConnector(
        limit=concurrency,
        limit_per_host=concurrency,
    )
    
    async with aiohttp.ClientSession(connector=connector) as session:
        # Warmup
        print("Warming up...")
        warmup_tasks = [make_request(session, url) for _ in range(min(10, concurrency))]
        await asyncio.gather(*warmup_tasks)
        
        print(f"Running {num_requests} requests with concurrency {concurrency}...")
        
        start_time = time.perf_counter()
        
        # Run requests in batches
        for batch_start in range(0, num_requests, concurrency):
            batch_size = min(concurrency, num_requests - batch_start)
            tasks = [make_request(session, url) for _ in range(batch_size)]
            batch_results = await asyncio.gather(*tasks)
            results.extend(batch_results)
            
            # Progress update
            done = batch_start + batch_size
            if done % 100 == 0 or done == num_requests:
                print(f"  Progress: {done}/{num_requests} ({done * 100 // num_requests}%)")
        
        total_time = time.perf_counter() - start_time
    
    # Calculate statistics
    latencies = [r.latency_ms for r in results if r.success]
    successful = sum(1 for r in results if r.success)
    failed = len(results) - successful
    
    if latencies:
        sorted_latencies = sorted(latencies)
        
        def percentile(data: list[float], p: float) -> float:
            idx = int(len(data) * p / 100)
            return data[min(idx, len(data) - 1)]
        
        report = LoadTestReport(
            total_requests=num_requests,
            successful=successful,
            failed=failed,
            total_time_sec=total_time,
            requests_per_second=successful / total_time if total_time > 0 else 0,
            avg_latency_ms=statistics.mean(latencies),
            min_latency_ms=min(latencies),
            max_latency_ms=max(latencies),
            p50_latency_ms=percentile(sorted_latencies, 50),
            p95_latency_ms=percentile(sorted_latencies, 95),
            p99_latency_ms=percentile(sorted_latencies, 99),
        )
    else:
        report = LoadTestReport(
            total_requests=num_requests,
            successful=0,
            failed=failed,
            total_time_sec=total_time,
            requests_per_second=0,
            avg_latency_ms=0,
            min_latency_ms=0,
            max_latency_ms=0,
            p50_latency_ms=0,
            p95_latency_ms=0,
            p99_latency_ms=0,
        )
    
    return report


async def run_mixed_load_test(
    base_url: str,
    num_requests: int,
    concurrency: int,
) -> LoadTestReport:
    """Run load test with mixed endpoint types."""
    endpoints = [
        ("/health", "GET", None),
        ("/api/v1/robots", "GET", None),
        ("/api/v1/deliveries", "GET", None),
        ("/api/v1/access-logs", "GET", None),
    ]
    
    results: list[TestResult] = []
    
    connector = aiohttp.TCPConnector(
        limit=concurrency,
        limit_per_host=concurrency,
    )
    
    async with aiohttp.ClientSession(connector=connector) as session:
        print("Warming up...")
        warmup_tasks = [
            make_request(session, f"{base_url}/health")
            for _ in range(min(10, concurrency))
        ]
        await asyncio.gather(*warmup_tasks)
        
        print(f"Running mixed load test: {num_requests} requests, concurrency {concurrency}")
        
        start_time = time.perf_counter()
        
        for batch_start in range(0, num_requests, concurrency):
            batch_size = min(concurrency, num_requests - batch_start)
            tasks = []
            
            for i in range(batch_size):
                endpoint, method, data = endpoints[(batch_start + i) % len(endpoints)]
                url = f"{base_url.rstrip('/')}{endpoint}"
                tasks.append(make_request(session, url, method, data))
            
            batch_results = await asyncio.gather(*tasks)
            results.extend(batch_results)
            
            done = batch_start + batch_size
            if done % 100 == 0 or done == num_requests:
                print(f"  Progress: {done}/{num_requests}")
        
        total_time = time.perf_counter() - start_time
    
    # Calculate statistics (same as above)
    latencies = [r.latency_ms for r in results if r.success]
    successful = sum(1 for r in results if r.success)
    failed = len(results) - successful
    
    if latencies:
        sorted_latencies = sorted(latencies)
        
        def percentile(data: list[float], p: float) -> float:
            idx = int(len(data) * p / 100)
            return data[min(idx, len(data) - 1)]
        
        return LoadTestReport(
            total_requests=num_requests,
            successful=successful,
            failed=failed,
            total_time_sec=total_time,
            requests_per_second=successful / total_time if total_time > 0 else 0,
            avg_latency_ms=statistics.mean(latencies),
            min_latency_ms=min(latencies),
            max_latency_ms=max(latencies),
            p50_latency_ms=percentile(sorted_latencies, 50),
            p95_latency_ms=percentile(sorted_latencies, 95),
            p99_latency_ms=percentile(sorted_latencies, 99),
        )
    else:
        return LoadTestReport(
            total_requests=num_requests,
            successful=0,
            failed=failed,
            total_time_sec=total_time,
            requests_per_second=0,
            avg_latency_ms=0,
            min_latency_ms=0,
            max_latency_ms=0,
            p50_latency_ms=0,
            p95_latency_ms=0,
            p99_latency_ms=0,
        )


def main():
    parser = argparse.ArgumentParser(description="Load test StairDOC API")
    parser.add_argument(
        "--url",
        default="http://localhost:8000",
        help="Base URL of the API",
    )
    parser.add_argument(
        "--requests",
        type=int,
        default=1000,
        help="Number of requests to make",
    )
    parser.add_argument(
        "--concurrency",
        type=int,
        default=50,
        help="Number of concurrent requests",
    )
    parser.add_argument(
        "--endpoint",
        default="/health",
        help="Endpoint to test",
    )
    parser.add_argument(
        "--mixed",
        action="store_true",
        help="Run mixed endpoint test",
    )
    
    args = parser.parse_args()
    
    print(f"""
╔══════════════════════════════════════════════════════════════╗
║              StairDOC API Load Test                          ║
║                                                              ║
║  Target: 1000+ requests/min (17+ req/sec)                    ║
╚══════════════════════════════════════════════════════════════╝
    
Configuration:
  URL:         {args.url}
  Requests:    {args.requests}
  Concurrency: {args.concurrency}
  Mode:        {'Mixed' if args.mixed else f'Single endpoint ({args.endpoint})'}
""")
    
    if args.mixed:
        report = asyncio.run(run_mixed_load_test(
            args.url,
            args.requests,
            args.concurrency,
        ))
    else:
        report = asyncio.run(run_load_test(
            args.url,
            args.requests,
            args.concurrency,
            args.endpoint,
        ))
    
    print(report)
    
    # Exit with error code if test failed
    if report.requests_per_second < 17:
        exit(1)


if __name__ == "__main__":
    main()
