import psutil
import time
from datetime import datetime
import threading


class PerformanceMonitor:
    """
    Класс для мониторинга производительности приложения.
    """
    
    def __init__(self):
        self.start_time = time.time()
        self.metrics_history = []
        self.process = psutil.Process()
        
        self.thresholds = {
            'cpu_percent': 80.0,
            'memory_percent': 75.0,
            'thread_count': 50
        }

    def get_metrics(self) -> dict:
        try:
            metrics = {
                'timestamp': datetime.now(),
                'cpu_percent': self.process.cpu_percent(),
                'memory_percent': self.process.memory_percent(),
                'thread_count': len(self.process.threads()),
                'uptime': time.time() - self.start_time
            }
            
            self.metrics_history.append(metrics)
            
            if len(self.metrics_history) > 1000:
                self.metrics_history.pop(0)
                
            return metrics
            
        except Exception as e:
            return {
                'error': str(e),
                'timestamp': datetime.now()
            }

    def check_health(self) -> dict:
        metrics = self.get_metrics()
        
        if 'error' in metrics:
            return {'status': 'error', 'error': metrics['error']}
            
        health_status = {
            'status': 'healthy',
            'warnings': [],
            'timestamp': metrics['timestamp']
        }
        
        if metrics['cpu_percent'] > self.thresholds['cpu_percent']:
            health_status['warnings'].append(
                f"High CPU usage: {metrics['cpu_percent']}%"
            )
            health_status['status'] = 'warning'
            
        if metrics['memory_percent'] > self.thresholds['memory_percent']:
            health_status['warnings'].append(
                f"High memory usage: {metrics['memory_percent']}%"
            )
            health_status['status'] = 'warning'
            
        if metrics['thread_count'] > self.thresholds['thread_count']:
            health_status['warnings'].append(
                f"High thread count: {metrics['thread_count']}"
            )
            health_status['status'] = 'warning'
            
        return health_status

    def get_average_metrics(self) -> dict:
        if not self.metrics_history:
            return {"error": "No metrics available"}
            
        avg_metrics = {
            'avg_cpu': sum(m['cpu_percent'] for m in self.metrics_history) / len(self.metrics_history),
            'avg_memory': sum(m['memory_percent'] for m in self.metrics_history) / len(self.metrics_history),
            'avg_threads': sum(m['thread_count'] for m in self.metrics_history) / len(self.metrics_history),
            'samples_count': len(self.metrics_history)
        }
        
        return avg_metrics

    def log_metrics(self, logger) -> None:
        metrics = self.get_metrics()
        health = self.check_health()
        
        if 'error' not in metrics:
            logger.info(
                f"Performance metrics - "
                f"CPU: {metrics['cpu_percent']:.1f}%, "
                f"Memory: {metrics['memory_percent']:.1f}%, "
                f"Threads: {metrics['thread_count']}, "
                f"Uptime: {metrics['uptime']:.0f}s"
            )
            
        if health['status'] == 'warning':
            for warning in health['warnings']:
                logger.warning(f"Performance warning: {warning}")