<template>
  <div>
    <h2><el-icon :size="22" style="vertical-align:middle"><Setting /></el-icon> 电价配置</h2>
    <el-table :data="list" border stripe v-loading="loading" style="margin-top: 8px">
      <el-table-column prop="tierNo" label="档位" width="80" />
      <el-table-column prop="tierName" label="名称" width="120" />
      <el-table-column prop="lowerLimit" label="下限(度)" width="120" />
      <el-table-column prop="upperLimit" label="上限(度)" width="120">
        <template #default="{ row }">{{ row.upperLimit || '无上限' }}</template>
      </el-table-column>
      <el-table-column label="单价(元/度)" width="150">
        <template #default="{ row }">
          <el-input-number
            v-if="editingId === row.configId"
            v-model="editForm.unitPrice"
            :precision="4"
            :step="0.01"
            :min="0"
            size="small"
          />
          <span v-else>{{ row.unitPrice }}</span>
        </template>
      </el-table-column>
      <el-table-column label="操作" width="120">
        <template #default="{ row }">
          <template v-if="editingId === row.configId">
            <el-button size="small" type="success" @click="savePrice(row)">保存</el-button>
            <el-button size="small" @click="editingId = null">取消</el-button>
          </template>
          <el-button v-else size="small" type="primary" @click="startEdit(row)">编辑</el-button>
        </template>
      </el-table-column>
    </el-table>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { ElMessage } from 'element-plus'
import priceApi from '@/api/price'

const list = ref([])
const loading = ref(false)
const editingId = ref(null)
const editForm = ref({})

onMounted(() => fetchList())
async function fetchList() {
  loading.value = true
  try { list.value = (await priceApi.list()).data.data } finally { loading.value = false }
}

function startEdit(row) {
  editingId.value = row.configId
  editForm.value = { unitPrice: row.unitPrice }
}

async function savePrice(row) {
  await priceApi.update({ configId: row.configId, unitPrice: editForm.value.unitPrice })
  ElMessage.success('电价已更新')
  editingId.value = null
  fetchList()
}
</script>
